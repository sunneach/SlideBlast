-module (caster_mochiweb_app).
-include ("wf.inc").

-export ([
	start/2
]).

start(_, _) ->
	riak:start(["riak.config"]),
	default_process_cabinet_handler:start(),
	Options = [{ip, "127.0.0.1"}, {port, 8000}],
	Loop = fun loop/1,
	mochiweb_http:start([{name, mochiweb_example_app}, {loop, Loop}, {max, 2048} | Options]).

loop(Req) ->
	RequestBridge = simple_bridge:make_request(mochiweb_request_bridge, {Req, "./wwwroot"}),
	ResponseBridge = simple_bridge:make_response(mochiweb_response_bridge, {Req, "./wwwroot"}),
	nitrogen:init_request(RequestBridge, ResponseBridge),
	wf_handler:set_handler(named_route_handler, [
		% Modules...
		{"/", web_index},
		{"/view/", web_view},
		{"/img/", web_img},

		% Static directories...
		{"/nitrogen", static_file},
		{"/js", static_file},
		{"/images", static_file},
		{"/css", static_file}
	]),
	nitrogen:run().
