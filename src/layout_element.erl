-module (layout_element).
-include ("wf.inc").
-include ("caster.hrl").
-compile(export_all).

%% Custom element to define a full screen north, south, east, west, center
%% style layout. Uses a JQuery layout library.

% Required for a custom element.
reflect() -> record_info(fields, layout).

% Executes when the element is rendered.
render_element(_HtmlID, #layout { 
    class=Class,
    north=North,   north_options=NorthOpts,
    south=South,   south_options=SouthOpts, 
    east=East,     east_options=EastOpts, 
    west=West,     west_options=WestOpts,
    center=Center, center_options=CenterOpts
}) ->
    
    % Generate Javascript...
    Marker = wf:temp_id(),
    [NorthID, SouthID, EastID, WestID, CenterID] = [wf:temp_id() || _ <- lists:seq(1, 5)],
    wf:wire(Marker, wf:f("var l = jQuery(obj('me').parentNode).layout({ north: ~s, south: ~s, east:  ~s, west : ~s, center : ~s }); document.jquerylayouts.push(l);", [
        make_layout_opts(NorthID, NorthOpts),
        make_layout_opts(SouthID, SouthOpts),
        make_layout_opts(EastID, EastOpts),
        make_layout_opts(WestID, WestOpts),
        make_layout_opts(CenterID, CenterOpts)
    ])),

    % Output the panels...
    [
        #panel { show_if=(North /= undefined),  class=[Class, " ", NorthID, " jquerylayout north"], body=North },
        #panel { show_if=(South /= undefined),  class=[Class, " ", SouthID, " jquerylayout south"], body=South },
        #panel { show_if=(East /= undefined),   class=[Class, " ", EastID, " jquerylayout east"], body=East },
        #panel { show_if=(West /= undefined),   class=[Class, " ", WestID, " jquerylayout west"], body=West },
        #panel { show_if=(Center /= undefined), class=[Class, " ", CenterID, " jquerylayout center"], body=Center },
        #span { id=Marker, style="display: none;" }
    ].

make_layout_opts(ID, Opts) ->
    PreOpts = [
        {paneSelector, "." ++ ID}
    ],
    options_to_js(PreOpts ++ Opts).        

%% Options is a list of {Key,Value} tuples	
options_to_js(Options) ->
	F = fun({Key, Value}) ->
		if 
			is_list(Value) -> 
				wf:f("~s: \"~s\"", [Key, wf:js_escape(Value)]);
			is_atom(Value) andalso (Value == true orelse Value == false) ->
				wf:f("~s: ~s", [Key, Value]);
			is_atom(Value) ->
				wf:f("~s: \"~s\"", [Key, Value]);
			true -> 
				wf:f("~s: ~p", [Key, Value])
		end
	end,
	Options1 = [F(X) || X <- Options],
	Options2 = string:join(Options1, ","),
	wf:f("{ ~s }", [Options2]).
