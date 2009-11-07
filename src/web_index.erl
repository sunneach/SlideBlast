-module (web_index).
-include ("wf.inc").
-include ("caster.hrl").
-compile(export_all).

main() -> #template { file="./wwwroot/caster.html" }.

body() -> 
    #panel { id=panel, body=[
        "Upload a PDF or .ZIP file containing your slides...",
        #p{},
        #upload { tag=upload }
    ]}.

upload_event(upload, OriginalName, TempFile) ->
    wf:comet(fun() -> process_upload(OriginalName, TempFile) end).
    
show_status(Msg) ->
    wf:wire(statusPanel, [#appear{}]),
    wf:update(statusPanel, [Msg]),
    wf:flush().

process_upload(OriginalName, TempFile) ->
		caster_utils:seed_random(),
		
		% Try to process the file...
    case type(OriginalName) of
        unknown -> 
            % We don't recognize the file. 
            % Delete it and alert the user.
            file:delete(TempFile),
            wf:flash("Unknown file type.");
        Type -> 
            wf:update(panel, #panel { id=statusPanel, class=statusPanel }),
            show_status("Processing..."),
            
            % Split the uploaded file into slides...
            {ok, B} = file:read_file(TempFile),
            Slides = process_file(Type, TempFile, B),
            Slides1 = lists:flatten([Slides]),
            
            % Save the deck...
            DeckID = guid(),
            AdminToken = sm_guid(),
            Deck = #deck { admin_token=AdminToken, slides=Slides1 },
            deck:save_deck(DeckID, Deck),
        
            % Redirect to the web_view...
            URL = "/view/" ++ wf:to_list(DeckID) ++ "/" ++ wf:to_list(AdminToken),
            wf:redirect(URL)
    end.
    
    
    
%%% PROCESS_FILE/3 -
%%% Given a file, split it into #slide records.

process_file(zip, File, B) -> % ZIP
    % Unzip to memory.
    % Create a slide out of each file.
    show_status("Unzipping file..."),
    {ok, Results} = zip:unzip(B, [memory]),
    file:delete(File),
    F = fun({InnerFile, InnerB}, Acc) ->
        case type(InnerFile) of 
            unknown -> Acc;
            Type -> Acc ++ [process_file(Type, InnerFile, InnerB)]
        end
    end,
    lists:foldl(F, [], lists:sort(Results));
    
process_file(pdf, File, _B) -> % PDF
    % Call ghostscript to break into images. 
    % Create a slide out of each image.
    show_status("Splitting pdf..."),
    BList = caster_utils:pdf_to_pngs(File),
    file:delete(File),
    [process_file(png, undefined, B) || B <- BList];
    
process_file(Type, File, B) -> % IMAGE or TEXT
    % Create a slide out of the image or text file. 
    file:delete(File),
    new_slide(Type, B).
    
    

%%% NEW_SLIDE/2 -
%%% Given a type and a binary, create a new slide record.   

new_slide(Type, B) when ?IS_TEXT(Type) ->
    % This is text. 
    % Just save it to a blob.
    BlobID = guid(B),
    Slide = #slide { id=guid(), type=Type, blob_id=BlobID },
    deck:save_blob(BlobID, B),
    Slide;

new_slide(Type, B) when ?IS_IMAGE(Type) ->
    % This is an image. 
    % Create a thumbnail.
    % Save the image and the thumbnail to a blob.
    BlobID = guid(B),
    {ThumbnailID, Thumbnail} = make_thumbnail(BlobID, B),
    Slide = #slide { id=guid(), type=Type, blob_id=BlobID, thumbnail_blob_id=ThumbnailID },
    deck:save_blob(ThumbnailID, Thumbnail),
    deck:save_blob(BlobID, B),
    Slide.



%%% MAKE_THUMBNAIL/2
%%% Turn an image file into a thumbnail using Imagemagick.

make_thumbnail(BlobID, Data) ->
    % Save the blob to a file. 
    % Turn into a thumbnail.
    % Delete the file.
    File = wf:f("./scratch/~s", [BlobID]),
    file:write_file(File, Data),
    Thumbnail = caster_utils:create_thumbnail(File),
    file:delete(File),
    ThumbnailID = guid(Thumbnail),
    {ThumbnailID, Thumbnail}.



%%% PRIVATE FUNCTIONS

sm_guid() ->
    L = io_lib:format("~.36B", [random:uniform(trunc(math:pow(36, 3)))]),
    list_to_binary(L).

guid() ->
    L = io_lib:format("~.36B", [random:uniform(trunc(math:pow(36, 7)))]),
    list_to_binary(L).
    
guid(B) ->
    ID = erlang:md5(B),
    list_to_binary([io_lib:format("~2.16.0B", [X]) || X <- binary_to_list(ID)]).
    
%% Given a filename, return the file type.
type(Filename) -> inner_type(filename:extension(Filename)).
inner_type(".pdf") -> pdf;
inner_type(".zip") -> zip;
inner_type(".markdown") -> markdown;
inner_type(".sh") -> shell;
inner_type(".cs") -> cs;
inner_type(".cpp") -> cpp;
inner_type(".js") -> js;
inner_type(".java") -> java;
inner_type(".txt") -> text;
inner_type(".sql") -> sql;
inner_type(".xml") -> xml;
inner_type(".erl") -> erlang;
inner_type(".gif") -> gif;
inner_type(".jpg") -> jpeg;
inner_type(".png") -> png;
inner_type(_) -> unknown.