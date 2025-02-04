%%--------------------------------------------------------------------
%% Copyright (c) 2020 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

%% Define the default actions.
-module(emqx_web_hook_actions).

-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").
-include_lib("emqx_rule_engine/include/rule_actions.hrl").

-type(action_fun() :: fun((Data :: map(), Envs :: map()) -> Result :: any())).

-export_type([action_fun/0]).

-export([ on_resource_create/2
        , on_get_resource_status/2
        , on_resource_destroy/2
        ]).

-export([ on_action_create_data_to_webserver/2
        , on_action_data_to_webserver/2
        ]).

-define(RESOURCE_TYPE_WEBHOOK, 'web_hook').
-define(RESOURCE_CONFIG_SPEC, #{
    method => #{order => 1,
                type => string,
                enum => [<<"PUT">>,<<"POST">>],
                default => <<"POST">>,
                title => #{en => <<"Request Method">>,
                           zh => <<"请求方法"/utf8>>},
                description => #{en => <<"Request Method">>,
                                 zh => <<"请求方法"/utf8>>}},
    url => #{order => 2,
             type => string,
             format => url,
             required => true,
             title => #{en => <<"Request URL">>,
                        zh => <<"请求 URL"/utf8>>},
             description => #{en => <<"Request URL">>,
                              zh => <<"请求 URL"/utf8>>}},
    headers => #{order => 3,
                 type => object,
                 schema => #{},
                 default => #{},
                 title => #{en => <<"Request Header">>,
                            zh => <<"请求头"/utf8>>},
                 description => #{en => <<"Request Header">>,
                                  zh => <<"请求头"/utf8>>}},
    connect_timeout => #{order => 4,
                         type => string,
                         default => <<"5s">>,
                         title => #{en => <<"Connect Timeout">>,
                                    zh => <<"连接超时时间"/utf8>>},
                         description => #{en => <<"Connect Timeout In Seconds">>,
                                          zh => <<"连接超时时间"/utf8>>}},
    request_timeout => #{order => 5,
                         type => string,
                         default => <<"5s">>,
                         title => #{en => <<"Request Timeout">>,
                                    zh => <<"请求超时时间"/utf8>>},
                         description => #{en => <<"Request Timeout In Seconds">>,
                                          zh => <<"请求超时时间"/utf8>>}},
    pool_size => #{order => 6,
                   type => number,
                   default => 8,
                   title => #{en => <<"Pool Size">>, zh => <<"连接池大小"/utf8>>},
                   description => #{en => <<"Connection Pool">>,
                                    zh => <<"连接池大小"/utf8>>}
                },
    enable_pipelining => #{order => 7,
                           type => boolean,
                           default => false,
                           title => #{en => <<"Enable Pipelining">>, zh => <<"Enable Pipelining"/utf8>>},
                           description => #{en => <<"Whether to enable HTTP Pipelining">>,
                                            zh => <<"是否开启 HTTP Pipelining"/utf8>>}
                },
    cacertfile => #{order => 8,
                    type => file,
                    default => <<"">>,
                    title => #{en => <<"CA Certificate File">>,
                               zh => <<"CA 证书文件"/utf8>>},
                    description => #{en => <<"CA Certificate file">>,
                                     zh => <<"CA 证书文件"/utf8>>}},
    keyfile => #{order => 9,
                 type => file,
                 default => <<"">>,
                 title =>#{en => <<"SSL Key">>,
                           zh => <<"SSL Key"/utf8>>},
                 description => #{en => <<"Your ssl keyfile">>,
                                  zh => <<"SSL 私钥"/utf8>>}},
    certfile => #{order => 10,
                  type => file,
                  default => <<"">>,
                  title =>#{en => <<"SSL Cert">>,
                            zh => <<"SSL Cert"/utf8>>},
                  description => #{en => <<"Your ssl certfile">>,
                                   zh => <<"SSL 证书"/utf8>>}},
    verify => #{order => 11,
                type => boolean,
                default => false,
                title =>#{en => <<"Verify Server Certfile">>,
                          zh => <<"校验服务器证书"/utf8>>},
                description => #{en => <<"Whether to verify the server certificate. By default, the client will not verify the server's certificate. If verification is required, please set it to true.">>,
                                 zh => <<"是否校验服务器证书。 默认客户端不会去校验服务器的证书，如果需要校验，请设置成true。"/utf8>>}}
}).

-define(ACTION_PARAM_RESOURCE, #{
    order => 0,
    type => string,
    required => true,
    title => #{en => <<"Resource ID">>,
               zh => <<"资源 ID"/utf8>>},
    description => #{en => <<"Bind a resource to this action">>,
                     zh => <<"给动作绑定一个资源"/utf8>>}
}).

-define(ACTION_DATA_SPEC, #{
    '$resource' => ?ACTION_PARAM_RESOURCE,
    payload_tmpl => #{
        order => 1,
        type => string,
        input => textarea,
        required => false,
        default => <<"">>,
        title => #{en => <<"Payload Template">>,
                   zh => <<"消息内容模板"/utf8>>},
        description => #{en => <<"The payload template, variable interpolation is supported. If using empty template (default), then the payload will be all the available vars in JSON format">>,
                         zh => <<"消息内容模板，支持变量。若使用空模板（默认），消息内容为 JSON 格式的所有字段"/utf8>>}
    }
}).

-resource_type(#{name => ?RESOURCE_TYPE_WEBHOOK,
    create => on_resource_create,
    status => on_get_resource_status,
    destroy => on_resource_destroy,
    params => ?RESOURCE_CONFIG_SPEC,
    title => #{en => <<"WebHook">>,
               zh => <<"WebHook"/utf8>>},
    description => #{en => <<"WebHook">>,
                     zh => <<"WebHook"/utf8>>}
}).

-rule_action(#{name => data_to_webserver,
    category => data_forward,
    for => '$any',
    create => on_action_create_data_to_webserver,
    params => ?ACTION_DATA_SPEC,
    types => [?RESOURCE_TYPE_WEBHOOK],
    title => #{en => <<"Data to Web Server">>,
               zh => <<"发送数据到 Web 服务"/utf8>>},
    description => #{en => <<"Forward Messages to Web Server">>,
                     zh => <<"将数据转发给 Web 服务"/utf8>>}
}).

%%------------------------------------------------------------------------------
%% Actions for web hook
%%------------------------------------------------------------------------------

-spec(on_resource_create(binary(), map()) -> map()).
on_resource_create(ResId, Conf) ->
    {ok, _} = application:ensure_all_started(ehttpc),
    Options = pool_opts(Conf, ResId),
    PoolName = pool_name(ResId),
    start_resource(ResId, PoolName, Options),
    Conf#{<<"pool">> => PoolName, options => Options}.

start_resource(ResId, PoolName, Options) ->
    case ehttpc_pool:start_pool(PoolName, Options) of
        {ok, _} ->
            ?LOG(info, "Initiated Resource ~p Successfully, ResId: ~p",
                 [?RESOURCE_TYPE_WEBHOOK, ResId]);
        {error, {already_started, _Pid}} ->
            on_resource_destroy(ResId, #{<<"pool">> => PoolName}),
            start_resource(ResId, PoolName, Options);
        {error, Reason} ->
            ?LOG(error, "Initiate Resource ~p failed, ResId: ~p, ~0p",
                 [?RESOURCE_TYPE_WEBHOOK, ResId, Reason]),
            error({{?RESOURCE_TYPE_WEBHOOK, ResId}, create_failed})
    end.

-spec(on_get_resource_status(binary(), map()) -> map()).
on_get_resource_status(ResId, #{<<"url">> := Url}) ->
    #{is_alive =>
        case emqx_rule_utils:http_connectivity(Url) of
            ok -> true;
            {error, Reason} ->
                ?LOG(error, "Connectivity Check for ~p failed, ResId: ~p, ~0p",
                     [?RESOURCE_TYPE_WEBHOOK, ResId, Reason]),
                false
        end}.

-spec(on_resource_destroy(binary(), map()) -> ok | {error, Reason::term()}).
on_resource_destroy(ResId, #{<<"pool">> := PoolName}) ->
    ?LOG(info, "Destroying Resource ~p, ResId: ~p", [?RESOURCE_TYPE_WEBHOOK, ResId]),
    case ehttpc_pool:stop_pool(PoolName) of
        ok ->
            ?LOG(info, "Destroyed Resource ~p Successfully, ResId: ~p", [?RESOURCE_TYPE_WEBHOOK, ResId]);
        {error, Reason} ->
            ?LOG(error, "Destroy Resource ~p failed, ResId: ~p, ~p", [?RESOURCE_TYPE_WEBHOOK, ResId, Reason]),
            error({{?RESOURCE_TYPE_WEBHOOK, ResId}, destroy_failed})
    end.

%% An action that forwards publish messages to a remote web server.
-spec on_action_create_data_to_webserver(binary(), map()) -> {[{atom(), term()}], map()}.
on_action_create_data_to_webserver(Id, Params) ->
    #{method := Method,
      path := Path,
      headers := Headers,
      payload_tmpl := PayloadTmpl,
      request_timeout := RequestTimeout,
      pool := Pool} = parse_action_params(Params),
    PayloadTokens = emqx_rule_utils:preproc_tmpl(PayloadTmpl),
    Params.

on_action_data_to_webserver(Selected, _Envs =
                            #{?BINDING_KEYS := #{
                                'Id' := Id,
                                'Method' := Method,
                                'Path' := Path,
                                'Headers' := Headers,
                                'PayloadTokens' := PayloadTokens,
                                'RequestTimeout' := RequestTimeout,
                                'Pool' := Pool},
                                clientid := ClientID}) ->
    Body = format_msg(PayloadTokens, Selected),
    Req = create_req(Method, Path, Headers, Body),
    case ehttpc:request(ehttpc_pool:pick_worker(Pool, ClientID), Method, Req, RequestTimeout) of
        {ok, StatusCode, _} when StatusCode >= 200 andalso StatusCode < 300 ->
            emqx_rule_metrics:inc_actions_success(Id);
        {ok, StatusCode, _, _} when StatusCode >= 200 andalso StatusCode < 300 ->
            emqx_rule_metrics:inc_actions_success(Id);
        {ok, StatusCode, _} ->
            ?LOG(warning, "[WebHook Action] HTTP request failed with status code: ~p", [StatusCode]),
            emqx_rule_metrics:inc_actions_error(Id);
        {ok, StatusCode, _, _} ->
            ?LOG(warning, "[WebHook Action] HTTP request failed with status code: ~p", [StatusCode]),
            emqx_rule_metrics:inc_actions_error(Id);
        {error, Reason} ->
            ?LOG(error, "[WebHook Action] HTTP request error: ~p", [Reason]),
            emqx_rule_metrics:inc_actions_error(Id)
    end.

format_msg([], Data) ->
    emqx_json:encode(Data);
format_msg(Tokens, Data) ->
     emqx_rule_utils:proc_tmpl(Tokens, Data).

%%------------------------------------------------------------------------------
%% Internal functions
%%------------------------------------------------------------------------------

create_req(Method, Path, Headers, _Body)
  when Method =:= get orelse Method =:= delete ->
    {Path, Headers};
create_req(_, Path, Headers, Body) ->
  {Path, Headers, Body}.

parse_action_params(Params = #{<<"url">> := URL}) ->
    try
        URIMap = uri_string:parse(add_default_scheme(URL)),
        #{method => method(maps:get(<<"method">>, Params, <<"POST">>)),
          path => path(URIMap),
          headers => headers(maps:get(<<"headers">>, Params, undefined)),
          payload_tmpl => maps:get(<<"payload_tmpl">>, Params, <<>>),
          request_timeout => cuttlefish_duration:parse(str(maps:get(<<"request_timeout">>, Params, <<"5s">>))),
          pool => maps:get(<<"pool">>, Params)}
    catch _:_ ->
        throw({invalid_params, Params})
    end.

path(#{path := <<>>, 'query' := Query}) ->
    <<"?", Query/binary>>;
path(#{path := Path, 'query' := Query}) ->
    <<Path/binary, "?", Query/binary>>;
path(#{path := <<>>}) ->
    <<"/">>;
path(#{path := Path}) ->
    Path.

method(GET) when GET == <<"GET">>; GET == <<"get">> -> get;
method(POST) when POST == <<"POST">>; POST == <<"post">> -> post;
method(PUT) when PUT == <<"PUT">>; PUT == <<"put">> -> put;
method(DEL) when DEL == <<"DELETE">>; DEL == <<"delete">> -> delete.

headers(undefined) -> [];
headers(Headers) when is_list(Headers) -> Headers;
headers(Headers) when is_map(Headers) ->
    maps:fold(fun(K, V, Acc) ->
            [{str(K), str(V)} | Acc]
        end, [], Headers).

str(Str) when is_list(Str) -> Str;
str(Atom) when is_atom(Atom) -> atom_to_list(Atom);
str(Bin) when is_binary(Bin) -> binary_to_list(Bin).

add_default_scheme(<<"http://", _/binary>> = URL) ->
    URL;
add_default_scheme(<<"https://", _/binary>> = URL) ->
    URL;
add_default_scheme(URL) ->
    <<"http://", URL/binary>>.

pool_opts(Params = #{<<"url">> := URL}, ResId) ->
    #{host := Host0, scheme := Scheme} = URIMap = uri_string:parse(binary_to_list(add_default_scheme(URL))),
    Port = maps:get(port, URIMap, case Scheme of
                                      "https" -> 443;
                                      _ -> 80
                                  end),
    Host = case inet:parse_address(Host0) of
                       {ok, {_,_,_,_} = Addr} -> Addr;
                       {ok, {_,_,_,_,_,_,_,_} = Addr} -> Addr;
                       {error, einval} -> Host0
                   end,
    Inet = case Host of
               {_,_,_,_} -> inet;
               {_,_,_,_,_,_,_,_} -> inet6;
               _ ->
                   case inet:getaddr(Host, inet6) of
                       {error, _} -> inet;
                       {ok, _} -> inet6
                   end
           end,
    PoolSize = maps:get(<<"pool_size">>, Params, 32),
    ConnectTimeout = cuttlefish_duration:parse(str(maps:get(<<"connect_timeout">>, Params, <<"5s">>))),
    TransportOpts =
        case Scheme =:= "https" of
            true  -> [Inet | get_ssl_opts(Params, ResId)];
            false -> [Inet]
        end,
    Opts = case Scheme =:= "https"  of
               true  -> [{transport_opts, TransportOpts}, {transport, ssl}];
               false -> [{transport_opts, TransportOpts}]
           end,
    [{host, Host},
     {port, Port},
     {enable_pipelining, maps:get(<<"enable_pipelining">>, Params, false)},
     {pool_size, PoolSize},
     {pool_type, hash},
     {connect_timeout, ConnectTimeout},
     {retry, 5},
     {retry_timeout, 1000} | Opts].

pool_name(ResId) ->
    list_to_atom("webhook:" ++ str(ResId)).

get_ssl_opts(Opts, ResId) ->
    KeyFile = maps:get(<<"keyfile">>, Opts, undefined),
    CertFile = maps:get(<<"certfile">>, Opts, undefined),
    CAFile = maps:get(<<"cacertfile">>, Opts, undefined),
    Filter = fun(Opts1) ->
                     [{K, V} || {K, V} <- Opts1,
                                    V =/= undefined,
                                    V =/= <<>>,
                                    V =/= "" ]
             end,
    Key = save_upload_file(KeyFile, ResId),
    Cert = save_upload_file(CertFile, ResId),
    CA = save_upload_file(CAFile, ResId),
    Verify = case maps:get(<<"verify">>, Opts, false) of
        false -> verify_none;
        true -> verify_peer
    end,
    case Filter([{keyfile, Key}, {certfile, Cert}, {cacertfile, CA}]) of
        [] -> [{verify, Verify}];
        SslOpts ->
            [{verify, Verify} | SslOpts]
    end.

save_upload_file(#{<<"file">> := <<>>, <<"filename">> := <<>>}, _ResId) -> "";
save_upload_file(FilePath, _) when is_binary(FilePath) -> binary_to_list(FilePath);
save_upload_file(#{<<"file">> := File, <<"filename">> := FileName}, ResId) ->
     FullFilename = filename:join([emqx:get_env(data_dir), rules, ResId, FileName]),
     ok = filelib:ensure_dir(FullFilename),
     case file:write_file(FullFilename, File) of
          ok ->
               binary_to_list(FullFilename);
          {error, Reason} ->
               logger:error("Store file failed, ResId: ~p, ~0p", [ResId, Reason]),
               error({ResId, store_file_fail})
     end;
save_upload_file(_, _) -> "".
