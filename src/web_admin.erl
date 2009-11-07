-module (web_admin).
-include ("wf.inc").
-compile(export_all).

main() -> #template { file="./wwwroot/caster_grid.html" }.

body() ->
	[
		#flash {},
		#label { text="Password" },
		#password { id=textBox },
		#button { id=start, text="Start", postback=start },
		#button { id=stop, text="Stop", postback=stop }
	].
	
event(start) ->
	P = wf:q(textBox),
	case P == "davidbowie" of
		true -> 
			application:set_env(caster, stopped, false),
			wf:flash("Started");
		false -> ok
	end;
	
event(stop) ->
	P = wf:q(textBox),
	case P == "davidbowie" of
		true -> 
			application:set_env(caster, stopped, true),
			wf:flash("Stopped");
		false -> ok
	end.