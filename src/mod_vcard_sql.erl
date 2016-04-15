%%%-------------------------------------------------------------------
%%% @author Evgeny Khramtsov <ekhramtsov@process-one.net>
%%% @copyright (C) 2016, Evgeny Khramtsov
%%% @doc
%%%
%%% @end
%%% Created : 13 Apr 2016 by Evgeny Khramtsov <ekhramtsov@process-one.net>
%%%-------------------------------------------------------------------
-module(mod_vcard_sql).

-compile([{parse_transform, ejabberd_sql_pt}]).

-behaviour(mod_vcard).

%% API
-export([init/2, get_vcard/2, set_vcard/4, search/4, remove_user/2,
	 import/3, export/1]).

-include("jlib.hrl").
-include("mod_vcard.hrl").
-include("logger.hrl").
-include("ejabberd_sql_pt.hrl").

%%%===================================================================
%%% API
%%%===================================================================
init(_Host, _Opts) ->
    ok.

get_vcard(LUser, LServer) ->
    case catch odbc_queries:get_vcard(LServer, LUser) of
	{selected, [{SVCARD}]} ->
	    case fxml_stream:parse_element(SVCARD) of
		{error, _Reason} -> error;
		VCARD -> [VCARD]
	    end;
	{selected, []} -> [];
	_ -> error
    end.

set_vcard(LUser, LServer, VCARD,
	  #vcard_search{user = {User, _},
			fn = FN,
			lfn = LFN,
			family = Family,
			lfamily = LFamily,
			given = Given,
			lgiven = LGiven,
			middle = Middle,
			lmiddle = LMiddle,
			nickname = Nickname,
			lnickname = LNickname,
			bday = BDay,
			lbday = LBDay,
			ctry = CTRY,
			lctry = LCTRY,
			locality = Locality,
			llocality = LLocality,
			email = EMail,
			lemail = LEMail,
			orgname = OrgName,
			lorgname = LOrgName,
			orgunit = OrgUnit,
			lorgunit = LOrgUnit}) ->
    SVCARD = fxml:element_to_binary(VCARD),
    odbc_queries:set_vcard(LServer, LUser, BDay, CTRY,
			   EMail, FN, Family, Given, LBDay,
			   LCTRY, LEMail, LFN, LFamily,
			   LGiven, LLocality, LMiddle,
			   LNickname, LOrgName, LOrgUnit,
			   Locality, Middle, Nickname, OrgName,
			   OrgUnit, SVCARD, User).

search(LServer, Data, AllowReturnAll, MaxMatch) ->
    MatchSpec = make_matchspec(LServer, Data),
    if (MatchSpec == <<"">>) and not AllowReturnAll -> [];
       true ->
	    Limit = case MaxMatch of
			infinity ->
			    <<"">>;
			Val ->
			    [<<" LIMIT ">>, jlib:integer_to_binary(Val)]
		    end,
	   case catch ejabberd_odbc:sql_query(
			LServer,
			[<<"select username, fn, family, given, "
			   "middle,        nickname, bday, ctry, "
			   "locality,        email, orgname, orgunit "
			   "from vcard_search ">>,
			 MatchSpec, Limit, <<";">>]) of
	       {selected,
		[<<"username">>, <<"fn">>, <<"family">>, <<"given">>,
		 <<"middle">>, <<"nickname">>, <<"bday">>, <<"ctry">>,
		 <<"locality">>, <<"email">>, <<"orgname">>,
		 <<"orgunit">>], Rs} when is_list(Rs) ->
		   Rs;
	       Error ->
		   ?ERROR_MSG("~p", [Error]), []
	   end
    end.

remove_user(LUser, LServer) ->
    ejabberd_odbc:sql_transaction(
      LServer,
      fun() ->
              ejabberd_odbc:sql_query_t(
                ?SQL("delete from vcard where username=%(LUser)s")),
              ejabberd_odbc:sql_query_t(
                ?SQL("delete from vcard_search where lusername=%(LUser)s"))
      end).

export(_Server) ->   
    [{vcard,
      fun(Host, #vcard{us = {LUser, LServer}, vcard = VCARD})
            when LServer == Host ->
              Username = ejabberd_odbc:escape(LUser),
              SVCARD =
                  ejabberd_odbc:escape(fxml:element_to_binary(VCARD)),
              [[<<"delete from vcard where username='">>, Username, <<"';">>],
               [<<"insert into vcard(username, vcard) values ('">>,
                Username, <<"', '">>, SVCARD, <<"');">>]];
         (_Host, _R) ->
              []
      end},
     {vcard_search,
      fun(Host, #vcard_search{user = {User, LServer}, luser = LUser,
                              fn = FN, lfn = LFN, family = Family,
                              lfamily = LFamily, given = Given,
                              lgiven = LGiven, middle = Middle,
                              lmiddle = LMiddle, nickname = Nickname,
                              lnickname = LNickname, bday = BDay,
                              lbday = LBDay, ctry = CTRY, lctry = LCTRY,
                              locality = Locality, llocality = LLocality,
                              email = EMail, lemail = LEMail,
                              orgname = OrgName, lorgname = LOrgName,
                              orgunit = OrgUnit, lorgunit = LOrgUnit})
            when LServer == Host ->
              Username = ejabberd_odbc:escape(User),
              LUsername = ejabberd_odbc:escape(LUser),
              SFN = ejabberd_odbc:escape(FN),
              SLFN = ejabberd_odbc:escape(LFN),
              SFamily = ejabberd_odbc:escape(Family),
              SLFamily = ejabberd_odbc:escape(LFamily),
              SGiven = ejabberd_odbc:escape(Given),
              SLGiven = ejabberd_odbc:escape(LGiven),
              SMiddle = ejabberd_odbc:escape(Middle),
              SLMiddle = ejabberd_odbc:escape(LMiddle),
              SNickname = ejabberd_odbc:escape(Nickname),
              SLNickname = ejabberd_odbc:escape(LNickname),
              SBDay = ejabberd_odbc:escape(BDay),
              SLBDay = ejabberd_odbc:escape(LBDay),
              SCTRY = ejabberd_odbc:escape(CTRY),
              SLCTRY = ejabberd_odbc:escape(LCTRY),
              SLocality = ejabberd_odbc:escape(Locality),
              SLLocality = ejabberd_odbc:escape(LLocality),
              SEMail = ejabberd_odbc:escape(EMail),
              SLEMail = ejabberd_odbc:escape(LEMail),
              SOrgName = ejabberd_odbc:escape(OrgName),
              SLOrgName = ejabberd_odbc:escape(LOrgName),
              SOrgUnit = ejabberd_odbc:escape(OrgUnit),
              SLOrgUnit = ejabberd_odbc:escape(LOrgUnit),
              [[<<"delete from vcard_search where lusername='">>,
                LUsername, <<"';">>],
               [<<"insert into vcard_search(        username, "
                  "lusername, fn, lfn, family, lfamily, "
                  "       given, lgiven, middle, lmiddle, "
                  "nickname, lnickname,        bday, lbday, "
                  "ctry, lctry, locality, llocality,   "
                  "     email, lemail, orgname, lorgname, "
                  "orgunit, lorgunit)values (">>,
                <<"        '">>, Username, <<"', '">>, LUsername,
                <<"',        '">>, SFN, <<"', '">>, SLFN,
                <<"',        '">>, SFamily, <<"', '">>, SLFamily,
                <<"',        '">>, SGiven, <<"', '">>, SLGiven,
                <<"',        '">>, SMiddle, <<"', '">>, SLMiddle,
                <<"',        '">>, SNickname, <<"', '">>, SLNickname,
                <<"',        '">>, SBDay, <<"', '">>, SLBDay,
                <<"',        '">>, SCTRY, <<"', '">>, SLCTRY,
                <<"',        '">>, SLocality, <<"', '">>, SLLocality,
                <<"',        '">>, SEMail, <<"', '">>, SLEMail,
                <<"',        '">>, SOrgName, <<"', '">>, SLOrgName,
                <<"',        '">>, SOrgUnit, <<"', '">>, SLOrgUnit,
                <<"');">>]];
         (_Host, _R) ->
              []
      end}].

import(_, _, _) ->
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================
make_matchspec(LServer, Data) ->
    filter_fields(Data, <<"">>, LServer).

filter_fields([], Match, _LServer) ->
    case Match of
	<<"">> -> <<"">>;
	_ -> [<<" where ">>, Match]
    end;
filter_fields([{SVar, [Val]} | Ds], Match, LServer)
  when is_binary(Val) and (Val /= <<"">>) ->
    LVal = mod_vcard:string2lower(Val),
    NewMatch = case SVar of
		   <<"user">> -> make_val(Match, <<"lusername">>, LVal);
		   <<"fn">> -> make_val(Match, <<"lfn">>, LVal);
		   <<"last">> -> make_val(Match, <<"lfamily">>, LVal);
		   <<"first">> -> make_val(Match, <<"lgiven">>, LVal);
		   <<"middle">> -> make_val(Match, <<"lmiddle">>, LVal);
		   <<"nick">> -> make_val(Match, <<"lnickname">>, LVal);
		   <<"bday">> -> make_val(Match, <<"lbday">>, LVal);
		   <<"ctry">> -> make_val(Match, <<"lctry">>, LVal);
		   <<"locality">> ->
		       make_val(Match, <<"llocality">>, LVal);
		   <<"email">> -> make_val(Match, <<"lemail">>, LVal);
		   <<"orgname">> -> make_val(Match, <<"lorgname">>, LVal);
		   <<"orgunit">> -> make_val(Match, <<"lorgunit">>, LVal);
		   _ -> Match
	       end,
    filter_fields(Ds, NewMatch, LServer);
filter_fields([_ | Ds], Match, LServer) ->
    filter_fields(Ds, Match, LServer).

make_val(Match, Field, Val) ->
    Condition = case str:suffix(<<"*">>, Val) of
		  true ->
		      Val1 = str:substr(Val, 1, byte_size(Val) - 1),
		      SVal = <<(ejabberd_odbc:escape_like(Val1))/binary,
			       "%">>,
		      [Field, <<" LIKE '">>, SVal, <<"'">>];
		  _ ->
		      SVal = ejabberd_odbc:escape(Val),
		      [Field, <<" = '">>, SVal, <<"'">>]
		end,
    case Match of
      <<"">> -> Condition;
      _ -> [Match, <<" and ">>, Condition]
    end.