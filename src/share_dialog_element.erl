-module (share_dialog_element).
-include ("wf.inc").
-include ("caster.hrl").
-compile(export_all).

%% Custom element to display a lightbox asking for the user's name.

% Required for a custom element.
reflect() -> record_info(fields, name_dialog).

% Executes when the element is rendered.
render_element(_HtmlID, _Record) ->
    wf:wire(closeButton, titleTextBox, #validate { validators=[
        #is_required { text="Required." }
    ]}),
    wf:wire(closeButton, authorTextBox, #validate { validators=[
        #is_required { text="Required." }
    ]}),
    #lightbox { id=share_lightbox, style="display: none;", body=[
        #panel { class=share_dialog, body=[
            #image { image="/images/SlideBlastLogoSmall.png" },
            #p{},
            "Title:",
            #p{},
            #textbox { id=titleTextBox, style="width: 500px;", next=authorTextBox },
            #p{},
            "Location:",
            #p{},
            #textbox { id=authorTextBox, style="width: 500px;", next=urlTextBox },
            #p{},
            "Share the link below with your attendees:",
            #p{},
            #textbox { id=urlTextBox, style="width: 500px;", next=closeButton },
            #p{},
            "Bookmark the current page to return to this slideshow as the presenter.",
            #p{},
            #button { id=closeButton, postback=close, text="Close", delegate=?MODULE }
        ]}
    ]}.
 
% Show the lightbox, and don't change slides in response to keyboard events.
show() ->
    wf:wire(share_lightbox, #show {}),
    Author = caster_utils:check_undefined(web_view:server_get(author)),
    Title  = caster_utils:check_undefined(web_view:server_get(title)),
    wf:wire(titleTextBox,"obj('me').value='" ++ Title ++"';"),
    wf:wire(authorTextBox,"obj('me').value='" ++ Author ++"';"),
    wf:wire(urlTextBox, "setShareURL(obj('me'));"),
    wf:wire("disableSlideControls();").

% OK button was pressed. Hide the lightbox.
show_titles(Author, Title) ->
    wf:wire(theTalkTitle,"obj('me').innerHTML='"   ++ caster_utils:check_undefined(Title) ++"';"),
    wf:wire(theCoordinates,"obj('me').innerHTML='Location: " ++ caster_utils:check_undefined(Author) ++"';").

event(close) ->
    Author = wf:q(authorTextBox),
    Title = wf:q(titleTextBox),
    show_titles(Author, Title),
    web_view:broadcast( fun() -> show_titles(Author,Title) end ),

    web_view:server_put(author, Author),
    web_view:server_put(title, Title),

    Title  = wf:q(titleTextBox),
    % Save changes to Riak.
    DeckID = web_view:server_get(deck_id),
    Deck = deck:load_deck(DeckID),
    NewDeck = Deck#deck { author=Author, title=Title },
    deck:save_deck(DeckID, NewDeck),
    wf:wire("enableSlideControls();"),
    wf:wire(share_lightbox, #hide {  }),
    case wf:state(showed_name_prompt) of
        true -> ok;
        _ ->
            wf:state(showed_name_prompt, true),
            ?PRINT(Author),
            name_dialog_element:show()
    end.
