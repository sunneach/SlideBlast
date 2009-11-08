-module (slide_controls_element).
-include ("wf.inc").
-include ("caster.hrl").
-compile(export_all).

%% Custom element to display a titlebar across the top of the screen with navigation buttons.
%% In addition, listens for keypresses, and advances to a new slide accordingly.

% Required for a custom element.
reflect() -> record_info(fields, slide_controls).

% Executes when the element is rendered.
render_element(_HtmlID, Record) ->
    IsAdmin = Record#slide_controls.is_admin,
    
    % Wire up a bunch of keys...
    case IsAdmin of 
        true -> wire_navigation_events();
        false -> ignore
    end,        
    wire_fullscreen_event(),

    % Display the buttons.
    #panel { class=slide_controls, body=[
        #image { style="float: right; margin-top: 7px;", image="/images/SlideBlastLogoSmall.png", actions=[
            #event { type=click, actions="window.open('/');" }
        ]},
        #button { show_if=IsAdmin, text="<<", class=control_button, delegate=?MODULE, postback={move, first}},
        #button { show_if=IsAdmin, text="<", class=control_button, delegate=?MODULE, postback={move, previous}},
        #button { show_if=IsAdmin, text=">", class=control_button, delegate=?MODULE, postback={move, next}},
        #button { show_if=IsAdmin, text=">>", class=control_button, delegate=?MODULE, postback={move, last}},
        #button { show_if=IsAdmin, text="Share", class=control_button, style="width: 80px;", delegate=?MODULE, postback=share},
        #button { text="Change Name", class=control_button, style="width: 150px;", delegate=?MODULE, postback=change_name },
        #span { text="Press 'f' to toggle fullscreen mode." }
    ]}.
    
% Wire navigation events. Only for Admins.
wire_navigation_events() ->
    wire_keydown_event(32, {move, next}), %SPACE
    wire_keydown_event(38, {move, previous}), %UP
    wire_keydown_event(37, {move, previous}), %LEFT
    wire_keydown_event(40, {move, next}), %DOWN
    wire_keydown_event(39, {move, next}), %RIGHT
    wire_keydown_event(8,  delete_slide),  %DELETE
    wire_keydown_event(46, delete_slide), %DELETE
    ok.
    
wire_fullscreen_event() ->
    wf:wire(#event { type=keydown, keycode=70, actions=[
        "if (!document.disable_slide_controls) { toggleFullScreen(); } else { return true; }"
    ]}).    

% Listen for a key, but only when 'disable_slide_controls' flag is off.    
wire_keydown_event(KeyCode, Postback) ->
    wf:wire(#event { type=keydown, keycode=KeyCode, actions=[
        "if (!document.disable_slide_controls) {",
        #event { delegate=?MODULE, postback=Postback },
        "} else { return true; }"
    ]}).    
    

%%% CALLED FROM ELEMENTS %%%

event({move, Direction}) ->
    web_view:move_in_direction(Direction);
    
event(delete_slide) ->
    web_view:delete_slide();
    
event(share) ->
    share_dialog_element:show();
    
event(change_name) ->
    name_dialog_element:show().