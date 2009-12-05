-module (share_dialog_element).
-include ("wf.inc").
-include ("caster.hrl").
-compile(export_all).

%% Custom element to display a lightbox asking for the user's name.

% Required for a custom element.
reflect() -> record_info(fields, name_dialog).

% Executes when the element is rendered.
render_element(_HtmlID, _Record) ->
    #lightbox { id=share_lightbox, style="display: none;", body=[
        #panel { class=share_dialog, body=[
            #image { image="/images/SlideBlastLogoSmall.png" },
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
    wf:wire(urlTextBox, "setShareURL(obj('me'));"),
    wf:wire("disableSlideControls();").

% OK button was pressed. Hide the lightbox.
event(close) ->
    wf:wire("enableSlideControls();"),
    wf:wire(share_lightbox, #hide {  }),
    case wf:state(showed_name_prompt) of
        true -> ok;
        _ ->
            wf:state(showed_name_prompt, true),
            name_dialog_element:show()
    end.

    