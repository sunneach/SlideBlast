-module (deck).
-include ("caster.hrl").
-export ([load_deck/1, save_deck/2]).
-export ([load_blob/1, save_blob/2]).
-export ([copy/3]).

-export([list_decks/0, archive_deck/2, clean/0, show_deck/1, all_decks/0, display_date/1, wipe/0, display/0]).

-define (DECK_BUCKET, <<"caster_deck">>).
-define (BLOB_BUCKET, <<"blob_bucket">>).


list_decks() ->
    {ok, Client} = riak:client_connect(node()),
    {ok, Keys}   = Client:list_keys(?DECK_BUCKET),
    Keys.
% removes slides and decks after RETENTION (7 days)
clean() ->
   [ archive_deck(DeckID,?RETENTION) || DeckID <- list_decks() ].

wipe() ->
   lists:foreach(fun(DeckID) -> archive_deck(DeckID,-1) end, list_decks()).

display() ->
  display_date(all_decks()).

all_decks() ->
   [ show_deck(DeckID) || DeckID <- list_decks() ].

display_date([]) -> ok;
display_date([Deck|L]) ->
  {DeckID,Adm,Slides,Title,Author,Days} = Deck,
  io:format("~3p days old-->~10s/~s (~p) ~20s~20s~n",[Days, DeckID, Adm, length(Slides), Title, Author]),
  display_date(L).

archive_deck(DeckID,Retention) ->
   {DeckID,_Adm,Slides,_Title,_Author,Diff} = show_deck(DeckID),
   case Diff > Retention of
     true -> remove_deck(DeckID,Slides);
     false -> ok
   end.

remove_deck(DeckID,[]) ->
    {ok, Client} = riak:client_connect(node()),
    Client:delete(?DECK_BUCKET, DeckID, 2),
    ?PRINT({deleted_deck,DeckID});

remove_deck(DeckID,[{_,_,_,BlobID,ThumbnailID,_}|Slides]) when ThumbnailID =/= undefined ->
    {ok, Client} = riak:client_connect(node()),
    Client:delete(?BLOB_BUCKET, BlobID, 2),
    ?PRINT({deleted_blob,BlobID}),
    Client:delete(?BLOB_BUCKET, ThumbnailID, 2),
    ?PRINT({deleted_thumbnail,ThumbnailID}),
    remove_deck(DeckID,Slides);

remove_deck(DeckID,[{_,_,_,BlobID,_,_}|Slides]) ->
    {ok, Client} = riak:client_connect(node()),
    Client:delete(?BLOB_BUCKET, BlobID, 2),
    ?PRINT({deleted_blob,BlobID}),
    remove_deck(DeckID,Slides).

show_deck(DeckID) ->
    try load_deck(DeckID) of
      {deck,Adm,Slides,Title,Author,Date} -> 
             {DeckID,Adm,Slides,Title,Author,daysdiff(Date)};
      {deck,Adm,Slides,Date} -> Author = undefined,
          Title  = undefined,
             {DeckID,Adm,Slides,Title,Author,daysdiff(Date)}
    catch _:_ -> 
             {DeckID,[],[],[],[],10000}
    end.

%private
daysdiff(Date) ->
    {Days,_} = calendar:seconds_to_daystime(caster_utils:now_seconds()-Date),
    Days.

copy(DeckID, NewDeckID, AdminToken) 
when is_binary(DeckID), is_binary(NewDeckID), is_binary(AdminToken) ->
    Deck = load_deck(DeckID),
    NewDeck = Deck#deck { admin_token=AdminToken },
    save_deck(NewDeckID, NewDeck),
    ok.    

% Load a slide deck from Riak.
load_deck(DeckID) ->
    {ok, Client} = riak:client_connect(node()),
    {ok, Obj} = Client:get(?DECK_BUCKET, DeckID, 2),
    riak_object:get_value(Obj).

% Save a slide deck to Riak.
save_deck(DeckID, Deck) ->
    {ok, Client} = riak:client_connect(node()),
    Obj1 = case Client:get(?DECK_BUCKET, DeckID, 2) of
        {ok, Obj} -> riak_object:update_value(Obj, Deck);
        _         -> riak_object:new(?DECK_BUCKET, DeckID, Deck)
    end,
    ok = Client:put(Obj1, 2).

% Load a blob from Riak. This can be an image, thumbnail, or text file.
load_blob(BlobID) ->
    {ok, C}   = riak:client_connect(node()),
    {ok, Obj} = C:get(?BLOB_BUCKET, BlobID, 2),
    riak_object:get_value(Obj).

% Save a blob to Riak.
save_blob(BlobID, Data) ->
    {ok, C} = riak:client_connect(node()),
    Obj1 = case C:get(?BLOB_BUCKET, BlobID, 2) of
        {ok, Obj} -> riak_object:update_value(Obj, Data);
        _         -> riak_object:new(?BLOB_BUCKET, BlobID, Data)
    end,
    ok = C:put(Obj1, 2).

    

    
