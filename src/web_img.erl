-module (web_img).
-include ("wf.inc").
-compile(export_all).

main() ->
    % Get the Key and Type...
    PathInfo = wf_context:path_info(),
    [Key, Type] = string:tokens(PathInfo, "/"),

    % Set the Content-Type header...
    wf_context:content_type("image/" ++ Type),
    
    % Load and return the Image...
    deck:load_blob(wf:to_binary(Key)).
    