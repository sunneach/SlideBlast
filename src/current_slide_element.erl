-module (current_slide_element).
-include ("wf.inc").
-include ("caster.hrl").
-compile(export_all).

%% Custom element to show the current slide. For better performance, this actually
%% preloads ALL slides on the page, and is then responsible for showing and hiding 
%% the panels to only show one slide at a time..

% Required for a custom element.
reflect() -> record_info(fields, current_slide).

% Executes when the element is rendered.
render_element(_HtmlID, Record) ->
    Deck = Record#current_slide.deck,
    #panel { id=currentSlideContainer, body=[
        [print_slide(X) || X <- Deck#deck.slides]
    ]}.
        
% Create a #panel element for each slide.
print_slide(Slide) ->
    SlideID = Slide#slide.id,
    #panel { 
        id=slide_id(SlideID), 
        class=current_slide, 
        style="display: none;", 
        body=print_slide_data(Slide#slide.type, Slide) 
    }.
    
% Display a markdown slide. Includes Javascript to call
% a Javascript markdown converter.
print_slide_data(markdown, Slide) ->
    Text = deck:load_blob(Slide#slide.blob_id),
    #panel { 
        class=markdown,
        id=temp_id,
        actions = wf:f("jQuery(obj('me')).html((new Showdown.converter()).makeHtml(\"~s\"));", [wf:js_escape(Text)])
    };

% Display a text slide. Includes Javascript to call the 
% Syntax Highlighter Javascript library. Slow, but it looks nice.
print_slide_data(Type, Slide) when ?IS_TEXT(Type) -> 
    Text = deck:load_blob(Slide#slide.blob_id),
    [
    wf:f("<pre class=\"brush: ~s\">", [Type]),
    clean(wf:to_list(Text)),
    "</pre>"
    ];
    
% Display an image slide. There is Javascript that fires every so
% often to make sure the image is scaled to width.
print_slide_data(Type, Slide) when ?IS_IMAGE(Type) ->
    Location = "/img/" ++ wf:to_list(Slide#slide.blob_id) ++ "/" ++ wf:to_list(Slide#slide.type),
    #image { image=Location }.

slide_id(SlideID) -> "cs" ++ wf:to_list(SlideID).



%%% CALLBACKS %%%

% Called by a comet process when we move to a new slide.
move_to_slide(SlideID) ->
    wf:wire("jQuery('.current_slide').hide();"),
    wf:wire(slide_id(SlideID), [
        #show { },
        "resizeCurrentSlide();"
    ]),
    ok.
    
clean([$<|T]) -> ["&lt;"|clean(T)];
clean([H|T]) -> [H|clean(T)];
clean([]) -> [].
