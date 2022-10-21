use t::APISIX 'no_plan';

repeat_each(1);
no_long_string();
no_root_location();

add_block_preprocessor(sub {
    my ($block) = @_;

    # setup default conf.yaml
    my $extra_yaml_config = $block->extra_yaml_config // <<_EOC_;
plugins:
    - serverless-pre-function
    - pipeline-request
_EOC_

    $block->set_value("extra_yaml_config", $extra_yaml_config);

    if (!$block->request) {
        $block->set_value("request", "GET /t");
    }

    if ((!defined $block->error_log) && (!defined $block->no_error_log)) {
        $block->set_value("no_error_log", "[error]");
    }
});

run_tests();

__DATA__

=== TEST 1: sanity
--- config
    location /t {
        content_by_lua_block {
            local test_cases = {
                {nodes = {
                    {url = "http://127.0.0.1"}
                }},
                {nodes = {}},
                {nodes = {
                    {uri = "http://127.0.0.1"}
                }},
                {nodes = {
                    {url = ""}
                }},
                {nodes = {
                    {url = "http://127.0.0.1", ssl_verify = "true"}
                }},
            }
            local plugin = require("apisix.plugins.pipeline-request")

            for _, case in ipairs(test_cases) do
                local ok, err = plugin.check_schema(case)
                ngx.say(ok and "done" or err)
            end
        }
    }
--- response_body
done
property "nodes" validation failed: expect array to have at least 1 items
property "nodes" validation failed: failed to validate item 1: property "url" is required
property "nodes" validation failed: failed to validate item 1: property "url" validation failed: string too short, expected at least 1, got 0
property "nodes" validation failed: failed to validate item 1: property "ssl_verify" validation failed: wrong type: expected boolean, got string



=== TEST 2: set test route
--- config
    location /t {
        content_by_lua_block {
            local data = {
                {
                    url = "/apisix/admin/routes/source",
                    data = {
                        plugins = {
                            ["serverless-pre-function"] = {
                                phase = "access",
                                functions =  {
                                    [[return function(conf, ctx)
                                        local core = require("apisix.core");
                                        core.response.set_header("X-Test", "source");
                                        core.response.exit(200, "Hello World!");
                                    end]],
                                }
                            },
                        },
                        uri = "/source"
                    },
                },
                {
                    url = "/apisix/admin/routes/transformer1",
                    data = {
                        plugins = {
                            ["serverless-pre-function"] = {
                                phase = "access",
                                functions =  {
                                    [[return function(conf, ctx)
                                        local core = require("apisix.core");
                                        local body = core.request.get_body();
                                        core.response.set_header("X-Test", "transformer1");
                                        core.response.exit(200, string.upper(body));
                                    end]],
                                }
                            },
                        },
                        uri = "/transformer1"
                    },
                },
                {
                    url = "/apisix/admin/routes/transformer2",
                    data = {
                        plugins = {
                            ["serverless-pre-function"] = {
                                phase = "access",
                                functions =  {
                                    [[return function(conf, ctx)
                                        local core = require("apisix.core");
                                        local body = core.request.get_body();
                                        core.response.set_header("X-Test", "transformer2");
                                        core.response.exit(200, string.reverse(body));
                                    end]],
                                }
                            },
                        },
                        uri = "/transformer2"
                    },
                },
            }

            local t = require("lib.test_admin").test

            for _, data in ipairs(data) do
                local code, body = t(data.url, ngx.HTTP_PUT, data.data)
                ngx.say(body)
            end
        }
    }
--- response_body eval
"passed\n" x 3



=== TEST 3: setup route (with single node, source)
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/routes/single',
                ngx.HTTP_PUT,
                [[{
                    "uri": "/single",
                    "plugins": {
                        "pipeline-request": {
                            "nodes": [
                                {
                                    "url": "http://127.0.0.1:1984/source"
                                }
                            ]
                        }
                    }
                }]]
            )

            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)
        }
    }
--- request
GET /t
--- response_body
passed



=== TEST 4: request single node
--- request
GET /single
--- response_body
Hello World!
--- response_headers
X-Test: source
