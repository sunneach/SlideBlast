-module (web_index).
-include ("wf.inc").
-include ("caster.hrl").
-compile(export_all).
-define (MAX_FILE_SIZE, 3 * 1024 * 1024).

main() -> #template { file="./wwwroot/caster.html" }.

body() -> 
    show_only(uploadPanel),
    [
        #panel { id=uploadPanel, body=[
            "Upload a PDF or .ZIP file containing your slides...",
            #p{},
            #upload { tag=upload, show_button=false }
        ]},
        #panel { id=progressPanel, style="display: none; text-align: center;", body=[
            #image { image="/images/progress.gif" }
        ]},
        #panel { id=statusPanel, style="display: none;", body="Processing..." }
    ].    
    
show_only(ID) ->
    wf:wire([
        #show { target=uploadPanel,   show_if=(uploadPanel == ID) },
        #show { target=progressPanel, show_if=(progressPanel == ID) },
        #show { target=statusPanel,   show_if=(statusPanel == ID) },
        #hide { target=uploadPanel,   show_if=(uploadPanel /= ID) },
        #hide { target=progressPanel, show_if=(progressPanel /= ID) },
        #hide { target=statusPanel,   show_if=(statusPanel /= ID) }
    ]).
    
start_upload_event(upload) ->
    show_only(progressPanel),
    ok.
    
finish_upload_event(upload, OriginalName, TempFile) ->
    wf:comet(fun() -> process_upload(OriginalName, TempFile) end),
    ok.
    
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
            show_only(statusPanel),
            wf:flush(),
                        
            % Split the uploaded file into slides...
            {ok, B} = file:read_file(TempFile),
            
            case process_file(Type, TempFile, B) of
                {ok, []} ->
                    wf:flash("No slides were uploaded."),
                    show_only(uploadPanel);
                                        
                {ok, Slides} -> 
                    % Save the deck...
                    DeckID = guid(),
                    AdminToken = sm_guid(),
                    Deck = #deck { admin_token=AdminToken, slides=Slides, created=caster_utils:now_seconds() },
                    deck:save_deck(DeckID, Deck),
        
                    % Redirect to the web_view...
                    URL = "/view/" ++ wf:to_list(DeckID) ++ "/" ++ wf:to_list(AdminToken),
                    wf:redirect(URL);
                
                _ ->
                    show_only(uploadPanel)
            end
    end.
    
show_status(Msg) ->
    wf:wire(statusPanel, [#appear{}]),
    wf:update(statusPanel, Msg),
    wf:flush().
    
%%% PROCESS_FILE/3 -
%%% Given a file, split it into #slide records.

process_file(zip, File, B) -> % ZIP
    % Unzip to memory.
    % Create a slide out of each file.
    show_status("Checking .zip file sizes..."),
    
    case check_zip_file_integrity(B) of 
        ok ->
            show_status("Unzipping files..."),
            {ok, Results} = zip:unzip(B, [memory]),
            file:delete(File),
            F = fun({InnerFile, InnerB}, Acc) ->
                show_status("Unzipping file: " ++ InnerFile ++ "..."),
                case type(InnerFile) of 
                    unknown -> 
                        Acc;
                    Type -> 
                        {ok, Slides} = process_file(Type, InnerFile, InnerB),
                        Acc ++ Slides
                end
            end,
            Slides = lists:foldl(F, [], lists:sort(Results)),
            {ok, lists:flatten(Slides)};
            
        invalid_zip ->
            Msg = wf:f("~s is not a valid zip file.", [File]),
            wf:flash(Msg),
            file:delete(File),
            {error, invalid_zip};
            
        {too_big, BigFile} ->
            Msg = wf:f("~s was too big.", [BigFile]),
            wf:flash(Msg),
            file:delete(File),
            {error, too_big}
    end;            
            
    
process_file(pdf, File, _B) -> % PDF
    % Call ghostscript to break into images. 
    % Create a slide out of each image.
    show_status("Splitting pdf..."),
    BList = caster_utils:pdf_to_pngs(File),
    file:delete(File),
    Slides = [begin
        {ok, S} = process_file(png, undefined, B),
        S
    end || B <- BList],
    {ok, lists:flatten(Slides)};
    
process_file(Type, File, B) -> % IMAGE or TEXT
    % Create a slide out of the image or text file. 
    file:delete(File),
    Slide = new_slide(Type, B),
    {ok, lists:flatten([Slide])}.
    
    

%%% NEW_SLIDE/2 -
%%% Given a type and a binary, create a new slide record.   

new_slide(Type, B) when ?IS_TEXT(Type) ->
    % This is text. 
    % Just save it to a blob.
    BlobID = guid(B),
    Slide = #slide { 
        id=guid(), type=Type, blob_id=BlobID, created=caster_utils:now_seconds() 
    },
    deck:save_blob(BlobID, B),
    Slide;

new_slide(Type, B) when ?IS_IMAGE(Type) ->
    % This is an image. 
    % Create a thumbnail.
    % Save the image and the thumbnail to a blob.
    BlobID = guid(B),
    {ThumbnailID, Thumbnail} = make_thumbnail(BlobID, B),
    Slide = #slide { 
        id=guid(), type=Type, blob_id=BlobID, thumbnail_blob_id=ThumbnailID, 
        created=caster_utils:now_seconds() 
    },
    deck:save_blob(ThumbnailID, Thumbnail),
    deck:save_blob(BlobID, B),
    Slide.


%%% CHECK_ZIP_FILE_INTEGRITY/1
%%% Make sure that we don't get a huge uploaded file.
%%% Return either 'ok', 'invalid_zip', or {too_big, Filename}
check_zip_file_integrity(B) ->
    case zip:list_dir(B, [cooked]) of
        {ok, ZipFiles} ->
            ZipFiles1 = [X || X <- ZipFiles, is_record(X, zip_file)],
            check_zip_file_sizes(lists:flatten([ZipFiles1]));
        {error, _} ->
            invalid_zip
    end.
    

check_zip_file_sizes([ZipFile|ZipFiles]) ->
    Name = ZipFile#zip_file.name,
    FileInfo = ZipFile#zip_file.info,
    Size = FileInfo#file_info.size,
    case Size > ?MAX_FILE_SIZE of
        true -> 
            {too_big, Name};
        false -> 
            check_zip_file_sizes(ZipFiles)
    end;
    
check_zip_file_sizes([]) -> ok.    


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