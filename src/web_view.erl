-module (web_view).
-include ("wf.inc").
-include ("caster.hrl").
-compile(export_all).

%%% LAYOUT %%%

main() -> #template { file="./wwwroot/caster_grid.html" }.

body() ->
    % Get the DeckID from PathInfo.
    % Load the Deck from Riak.
    {DeckID, AdminToken} = case string:tokens(wf_context:path_info(), "/") of
        [A]    -> {wf:to_binary(A), <<>>};
        [A, B] -> {wf:to_binary(A), wf:to_binary(B)}
    end,
    Deck = deck:load_deck(DeckID),
    IsAdmin = Deck#deck.admin_token == AdminToken,
    CurrentSlide = hd(Deck#deck.slides),
    
    % Start the comet process under the <DeckID> pool.
    % This is used for broadcasting events to other attendees
    % viewing this slide deck.
    {ok, Pid} = wf:comet_global(fun() -> comet_loop() end, DeckID),
    
    % Save things into session. 
    % A little gross, but it's the easiest way to make sure that 
    % both postbacks and the comet process are seeing the same values.
    server_put(comet_pid, Pid),
    server_put(deck_id, DeckID),
    server_put(slide_ids, [X#slide.id || X <- Deck#deck.slides]),
    server_put(slide_id, CurrentSlide#slide.id),
    
    % Show either the name dialog or the share dialog.
    case IsAdmin of
        true -> share_dialog_element:show();
        false -> name_dialog_element:show()
    end,
    
    % Layout...
    [
        % Lightbox that prompts for the user's name...
        #name_dialog { },
        
        % Lightbox to share the link with attendees...
        #share_dialog { },
        
        % Main layout...
        #layout {
            class=main,
        
            % Slide controls on the top...
            north=#slide_controls { is_admin=IsAdmin },
            north_options = [{size, 60}, {spacing_open, 0}, {spacing_closed, 0}],
        
            % Slide list to the left...
            west=#slide_list { deck=Deck, is_admin=IsAdmin },
            west_options=[{size, 140}, {spacing_open, 0}, {spacing_closed, 0}],
        
            % Current slide in the center...
            center=#current_slide { deck=Deck, slide_id=CurrentSlide#slide.id },
            
            % Attendee list to the right...
            east=#attendee_list { deck_id=DeckID },
            east_options=[{size, 200}, {spacing_open, 0}, {spacing_closed, 0}]
        }
    ].
 
 
    
%%% EVENTS %%%

% The functions below are called in the context of whichever user
% initiates the action. They then call broadcast/1 to broadcast
% the event to all other Comet processess in the same pool 
% as this slideshow, updating the interface for all attendees.

move_to_slide(SlideID) -> 
    broadcast(fun() -> inner_move_to_slide(SlideID) end),
    inner_move_to_slide(SlideID).
    
inner_move_to_slide(NewSlideID) ->
    server_put(slide_id, NewSlideID),
    slide_list_element:move_to_slide(NewSlideID),
    current_slide_element:move_to_slide(NewSlideID),
    attendee_list_element:action(),
    ok.
    
    
move_in_direction(Direction) ->
    % Based on the selected direction, figure out the next slide to display.
    SlideID = server_get(slide_id),
    SlideIDs = server_get(slide_ids),
    NewSlideID = case Direction of
        first -> first(SlideIDs);
        previous -> previous(SlideIDs, SlideID);
        next -> next(SlideIDs, SlideID);
        last -> last(SlideIDs)
    end,
    case SlideID /= NewSlideID of
        true -> move_to_slide(NewSlideID);
        false -> ignore
    end.
    

sort_slides(Slides) -> 
    % Save to Riak.
    DeckID = server_get(deck_id),
    Deck = deck:load_deck(DeckID),
    NewDeck = Deck#deck { slides=Slides },
    deck:save_deck(DeckID, NewDeck),

    % Broadcast the new list.
    SlideIDs = [Slide#slide.id || Slide <- Slides],
    server_put(slide_ids, SlideIDs),
    broadcast(fun() -> inner_sort_slides(SlideIDs) end).
    
inner_sort_slides(SlideIDs) ->
    server_put(slide_ids, SlideIDs),
    slide_list_element:sort_slides(SlideIDs),
    attendee_list_element:action().
    
    
delete_slide() -> 
    % Save changes to Riak.
    DeckID = server_get(deck_id),
    Deck = deck:load_deck(DeckID),
    SlideID = server_get(slide_id),
    NewDeck = Deck#deck { slides=lists:keydelete(SlideID, 2, Deck#deck.slides) },
    deck:save_deck(DeckID, NewDeck),
    
    % Broadcast the deletion.
    broadcast(fun() -> inner_delete_slide() end), 
    inner_delete_slide().

inner_delete_slide() -> 
    SlideID = server_get(slide_id),
    SlideIDs = server_get(slide_ids),    
    case length(SlideIDs) > 1 of
        true -> 
            NewSlideID = case next(SlideIDs, SlideID) of
                SlideID -> previous(SlideIDs, SlideID);
                X -> X
            end,
            NewSlideIDs = SlideIDs -- [SlideID],
            server_put(slide_ids, NewSlideIDs),
            move_to_slide(NewSlideID),
            slide_list_element:delete_slide(SlideID),
            attendee_list_element:action();
        false -> ignore
    end.
    
    
%%% COMET %%%


% Helper to broadcast the specified function
% to all attendees viewing this slideshow.
broadcast(Function) ->
    DeckID = server_get(deck_id),
    Pid = server_get(comet_pid),
    wf:send_global(DeckID, {broadcasted, Function, Pid}),
    ok.
    
comet_loop() ->
    Self = self(),
    receive
        'INIT' -> 
            % 'INIT' is only sent to the first 
            % process to join the pool.
            move_in_direction(first),
            wf:flush(),
            comet_loop();
            
        {'JOIN', Pid} -> 
            % 'JOIN' is sent to _all_ processes in the pool
            % when a new process joins the pool. 
            F = fun() -> inner_move_to_slide(server_get(slide_id)) end,
            Pid ! { broadcasted, F, self() },
            comet_loop();
                   
        {broadcasted, Function, FromPid} when FromPid /= Self ->
            % Execute the broadcasted function as long as it wasn't
            % sent by us. 
            Function(),
            wf:flush(),
            comet_loop();
            
        _Other -> 
            comet_loop()
        
        after 3000 ->
            % If no activity, then call a function that will signal that 
            % our attendee is still connected, and loop.
            wf:wire(#function { function=fun() -> attendee_list_element:action(), [] end }),
            wf:flush(),
            comet_loop()            
    end.
    
    
    

%%% POSITION FUNCTIONS %%%

% Given a list of slides, get the first, previous, next, or last
% slide in the list.
    
first(SlideIDs) ->
    hd(SlideIDs).
    
previous(SlideIDs, SlideID) ->
    Pos = pos(SlideID, SlideIDs),
    case Pos > 1 of
        true -> lists:nth(Pos - 1, SlideIDs);
        false -> hd(SlideIDs)
    end.
    
next(SlideIDs, SlideID) ->
    Pos = pos(SlideID, SlideIDs),
    case Pos < length(SlideIDs) of
        true -> lists:nth(Pos + 1, SlideIDs);
        false -> hd(lists:reverse(SlideIDs))
    end.

last(SlideIDs) ->
    hd(lists:reverse(SlideIDs)).
    
pos(Member, List) -> pos(Member, List, 1).
pos(_, [], _) -> 0;
pos(Member, [Member|_], Pos) -> Pos;
pos(Member, [_|Rest], Pos) -> pos(Member, Rest, Pos + 1).


%%% SESSION ACCESS %%%

% Store and retrieve values from session,
% uniqueified by the current SeriesID. 
% Every new request to a Nitrogen page gets 
% a SeriesID, and the SeriesID stays the same
% across all postbacks and comet events.

server_put(Key, Value) ->
    SeriesID = wf_context:series_id(),
    wf:session({SeriesID, Key}, Value).

server_get(Key) ->
    SeriesID = wf_context:series_id(),
    wf:session({SeriesID, Key}).
    
