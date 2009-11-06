-module (deck).
-include ("caster.hrl").
-export ([load_deck/1, save_deck/2]).
-export ([load_blob/1, save_blob/2]).
-define (DECK_BUCKET, <<"caster_deck">>).
-define (BLOB_BUCKET, <<"blob_bucket">>).

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

    

    