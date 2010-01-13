-module (slide_list_element).
-include ("wf.inc").
-include ("caster.hrl").
-compile(export_all).


%% Custom element to display a thumbnailed list of slides and listen for events.
%% - If the user clicks on a slide, then move_to(SlideID) is called in web_view.
%% - If the user sorts the slides, then sort_slides(SlideIDs) is called in web_view.

% Required for a custom element.
reflect() -> record_info(fields, slide_list).

% Executes when the element is rendered.
render_element(_HtmlID, Record) ->
    Deck = Record#slide_list.deck,
    IsAdmin = Record#slide_list.is_admin,
    #panel { id=slideListContainer, body=[
        print_deck(Deck, IsAdmin) 
    ]}.

% Create the slides within a #sortblock element.
% If the slides are sorted, then fire a postback that calls sort_event(sort, [SlideIDs]).
print_deck(Deck, IsAdmin) ->
    Slides = [print_slide(X, IsAdmin) || X <- Deck#deck.slides],
    case IsAdmin of
        true -> #sortblock { id=slideList, tag=sort, items=Slides, delegate=?MODULE };
        false -> #panel { id=slideList, body=Slides }
    end.

% Create each slide as a #sortitem.
% If the slide is clicked, then fire a postback that calls event({move_to, SlideID}).
print_slide(Slide, IsAdmin) ->
    SlideID = Slide#slide.id,
    #sortitem { 
        id=slide_id(SlideID), class=slide, tag=Slide, 
        body=[
            #panel { class=slide_image_container, body=thumbnail(Slide#slide.type, Slide) }
        ],
        actions=#event { show_if=IsAdmin, type=mousedown, postback={move_to, SlideID}, delegate=?MODULE }
    }.

% Show the thumbnail for a text slide, which is just 
% the slide type in a little box.
thumbnail(Type, _Slide) when ?IS_TEXT(Type) -> 
    Types = [
        {ruby,"Ruby"}, {python,"Python"},{as3,"AS3"},{php,"PHP"},{markdown, "Markdown"}, 
        {text, "Text"}, {shell, ".sh"}, {csharp, "C#"}, {cpp, "C++"}, 
        {c, "C"}, {css, "CSS"}, {js, "Javascript"}, {java, "Java"}, {sql, "SQL"}, 
        {xml, "xml"},{erlang, "Erlang"} 
   ],
    proplists:get_value(Type, Types);

% Show the thumbnail for an image slide, which will actually
% load an image from Riak when it is rendered by the browser.
thumbnail(Type, Slide) when ?IS_IMAGE(Type) ->
    ThumbnailLocation = "/img/" ++ wf:to_list(Slide#slide.thumbnail_blob_id) ++ "/" ++ wf:to_list(Slide#slide.type),
    #image { 
        class=slide_image, 
        image=ThumbnailLocation
    }.

slide_id(SlideID) -> "s" ++ wf:to_list(SlideID).

%%% EVENTS %%%

event({move_to, SlideID}) -> web_view:move_to_slide(SlideID).

sort_event(_DeckID, SlideIDs) -> web_view:sort_slides(SlideIDs).

%%% CALLBACKS %%%

move_to_slide(SlideID) ->
    wf:wire("jQuery('.slide').removeClass('selected');"),
    wf:wire(slide_id(SlideID), #add_class { class=selected }).
    
sort_slides(SlideIDs) ->
    wf:wire(slideList, #hide {}),
    [wf:wire(slide_id(X), "jQuery(obj('slideList')).append(obj('me'));") || X <- SlideIDs],
    wf:wire(slideList, #appear { speed=300 }).
    
delete_slide(SlideID) ->
    wf:wire(slide_id(SlideID), #effect { effect=drop, speed=300 }).
    
