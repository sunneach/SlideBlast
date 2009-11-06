-include ("wf.inc").
-define (IS_TEXT(Type), (Type==markdown orelse Type == shell orelse Type==csharp orelse Type==cpp orelse Type==c orelse Type==css orelse Type==js orelse Type==java orelse Type==text orelse Type==sql orelse Type==xml orelse Type==erlang)).
-define (IS_IMAGE(Type), (Type==gif orelse Type==jpeg orelse Type==png)).
 
-record (deck, { admin_token, slides=[] }).
-record (slide, { id, type, blob_id, thumbnail_blob_id }).

-record (layout, {?ELEMENT_BASE(layout_element), north, south, east, west, center, north_options=[], south_options=[], east_options=[], west_options=[], center_options=[] }).

-record (slide_list, { ?ELEMENT_BASE(slide_list_element), deck, is_admin=false}).
-record (current_slide, { ?ELEMENT_BASE(current_slide_element), deck, slide_id }).
-record (slide_controls, { ?ELEMENT_BASE(slide_controls_element), is_admin=false }).
-record (attendee_list, {?ELEMENT_BASE(attendee_list_element), deck_id}).

-record (name_dialog, { ?ELEMENT_BASE(name_dialog_element) }).
-record (share_dialog, { ?ELEMENT_BASE(share_dialog_element) }).