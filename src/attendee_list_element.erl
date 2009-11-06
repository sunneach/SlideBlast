-module (attendee_list_element).
-include ("wf.inc").
-include ("caster.hrl").
-compile(export_all).
-record (attendee, {name, pid, last_update}).

%% Custom element to show a list of all attendees viewing this slide deck.
%% Show active attendees in black, and inactive attendees in gray.
%% An inactive attendee is an attendee whose web browser hasn't sent a "tick"
%% message in about 5 seconds.


% Required for a custom element.
reflect() -> record_info(fields, attendee_list).

% Executes when the element is rendered.
render_element(_HtmlID, Record) ->
    DeckID = Record#attendee_list.deck_id,
    {ok, Pid} = wf:comet_global(fun() -> comet_loop(DeckID) end, DeckID),
    web_view:server_put(attendee_comet_pid, Pid),
    [
        #span { class=attendee_title, text="Attendees" },
        #panel { id=attendeeList }
    ].
    
% Show the list of all connected attendees.
print_attendee_list(L) ->
    [begin
        #panel { id=attendee_id(X), class=attendee, body=X#attendee.name }
    end || X <- L].

% Add CSS classes to indicate the status of attendees.
% Add the 'selected' class to the current attendee.
% Add an 'old' class to any attendees who haven't checked in for a while.
color_attendee_list(L, LastTick) ->
    % Select the 
    wf:wire(attendee_id(self()), #add_class { class=selected }),
    [begin
        IsOld = timer:now_diff(LastTick, X#attendee.last_update) > (5 * 1000 * 1000),
        case IsOld of
            true -> wf:wire(attendee_id(X), #add_class { class="old" });
            false -> ignore
        end            
    end || X <- L].


    
%%% EVENTS %%%

action() ->
    DeckID = web_view:server_get(deck_id),
    case web_view:server_get(attendee_comet_pid) of
        undefined -> ignore;
        Pid -> wf:send_global(DeckID, {tick, Pid})
    end.
    
%%% COMET %%%
    
comet_loop(DeckID) ->
    web_view:server_put(attendee_comet_pid, self()),
    Me = #attendee { name="Joining...", pid=self(), last_update=now() },
    wf:send_global(DeckID, {hello, Me}), 
    comet_loop([Me], now()).
    
comet_loop(L, LastTick) ->
    receive
        {'JOIN', Pid} -> % Sent when any comet processes join.
            Pid!{latest_attendee_list, L},
            comet_loop(L, LastTick);
            
        {latest_attendee_list, NewL} when L /= NewL ->
            % We've been given a new attendee list. Update the web page.
            wf:update(attendeeList, print_attendee_list(NewL)),
            color_attendee_list(NewL, LastTick),
            wf:flush(),
            comet_loop(NewL, LastTick);
            
        {set_name, Name} ->
            % We've change our name. Broadcast to the pool..
            Me = lists:keyfind(self(), 3, L),
            NewMe = Me#attendee { name=Name },
            NewL = lists:sort(lists:keystore(self(), 3, L, NewMe)),
            DeckID = web_view:server_get(deck_id),
            wf:send_global(DeckID, {hello, NewMe}),
            comet_loop(NewL, LastTick);
        
        {hello, A} ->
            % Someone has changed their name. Update our attendee list...
            NewL = lists:sort(lists:keystore(A#attendee.pid, 3, L, A)),
            wf:update(attendeeList, print_attendee_list(NewL)),
            color_attendee_list(NewL, LastTick),
            wf:flush(),
            comet_loop(NewL, LastTick);
            
        {tick, Pid} ->
            % An attendee pid has sent a keepalive message. 
            % Recolor the attendee list.
            A = lists:keyfind(Pid, 3, L),
            NewL = lists:keystore(Pid, 3, L, A#attendee { last_update=now() }),
            NewLastTick = now(),
            color_attendee_list(NewL, NewLastTick),
            wf:flush(),
            comet_loop(NewL, NewLastTick);
            
        {'LEAVE', Pid} ->
            % An attendee has departed. Update and recolor the attendee list.
            NewL = lists:keydelete(Pid, 3, L),
            wf:update(attendeeList, print_attendee_list(NewL)),
            color_attendee_list(NewL, LastTick),
            wf:flush(),
            comet_loop(NewL, LastTick);
            
        _Other ->
            comet_loop(L, LastTick) 
end.
            
            
attendee_id(A) when is_record(A, attendee) -> attendee_id(A#attendee.pid);
attendee_id(Pid) when is_pid(Pid) -> "a" ++ clean(pid_to_list(Pid)).
    
clean([]) -> [];
clean([H|T]) when H >= $0 andalso H =< $9 -> [H|clean(T)];
clean([_|T]) -> clean(T).