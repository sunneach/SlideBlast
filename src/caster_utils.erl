-module (caster_utils).
-export ([pdf_to_pngs/1]).
-export ([create_thumbnail/1]).

%% Use GhostScript to break a .pdf into pngs.
pdf_to_pngs(File) -> pdf_to_png(File, 1).
pdf_to_png(File, PageNum) ->
    web_index:show_status("Processing page " ++ wf:to_list(PageNum) ++ "..."),
    Cmd = wf:f("./deps/scripts/pdf_to_png.sh \"~s\" ~p", [File, PageNum]),
    Opts = [use_stdio, stream, eof],
    Port = open_port({spawn, Cmd}, Opts),
    B = read_messages(Port, []),
    port_close(Port),
    case B of
        <<137,"PNG", _/binary>> -> [B|pdf_to_png(File, PageNum + 1)];
        _ -> []
    end.
    
%% Use Imagemagick to create a thumbnail of an image.
create_thumbnail(File) ->
    Cmd = wf:f("./deps/scripts/image_to_thumbnail.sh \"~s\"", [File]),
    Opts = [use_stdio, stream, eof],
    Port = open_port({spawn, Cmd}, Opts), 
    B = read_messages(Port, []),
    port_close(Port),
    B.

%% Private functions %%
read_messages(Port, Acc) ->
    receive
        {Port,eof} ->
            list_to_binary(lists:flatten(lists:reverse(Acc)));
        
        {Port, {data, B}} ->
            read_messages(Port, [B|Acc])
            
        after 5000 ->
            error
    end.
