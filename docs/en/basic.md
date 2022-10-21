# Basic usage

## Table of contents

- [Basic usage](#basic-usage)
  - [Table of contents](#table-of-contents)
  - [Single node](#single-node)
  - [Two nodes](#two-nodes)
  - [More nodes](#more-nodes)

## Single node

Use the following command to create a route:

```shell
curl -X PUT 'http://127.0.0.1:9180/apisix/admin/routes/1' \
--header 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
--header 'Content-Type: application/json' \
--data-raw '{
    "uri": "/single",
    "plugins": {
        "pipeline-request": {
            "nodes": [
                {
                    "url": "http://httpbin.org/anything"
                }
            ]
        }
    }
}'
```

Next we can request this route and you will see something like this.

```shell
curl http://127.0.0.1:9080/single -i
```

```text
HTTP/1.1 200 OK
Content-Type: application/json
Connection: keep-alive
Server: APISIX/2.15.0
Content-Length: 339
Date: Fri, 21 Oct 2022 15:43:30 GMT
Access-Control-Allow-Credentials: true
Access-Control-Allow-Origin: *

{
  "args": {}, 
  "data": "", 
  "files": {}, 
  "form": {}, 
  "headers": {
    "Accept": "*/*", 
    "Host": "127.0.0.1", 
    "User-Agent": "curl/7.81.0", 
    "X-Amzn-Trace-Id": "Root=1-6352be22-7d804953231baf6e46808431"
  }, 
  "json": null, 
  "method": "GET", 
  "origin": "1.1.1.1", 
  "url": "http://127.0.0.1/anything"
}
```

[Back to TOC](#table-of-contents)

## Two nodes

To perform this experiment, we had to create a route that would rewrite the request body when requested, rewriting all letters to uppercase.

```shell
curl -X PUT 'http://127.0.0.1:9180/apisix/admin/routes/t1' \
--header 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
--header 'Content-Type: application/json' \
--data-raw '{
    "uri": "/t1",
    "plugins": {
        "serverless-pre-function": {
            "phase": "access",
            "functions": [
                "return function(conf, ctx) local core = require(\"apisix.core\"); local body = core.request.get_body(); core.response.set_header(\"X-Test\", \"transformer1\"); core.response.exit(200, string.upper(body)); end"
            ]
        }
    }
}'
```

The core logic of this is as follows:

- Send a header: X-Test = transformer1
- Rewrite all letters to uppercase

```lua
return function(conf, ctx)
    local core = require("apisix.core")
    local body = core.request.get_body()
    core.response.set_header("X-Test", "transformer1")
    core.response.exit(200, string.upper(body))
end
```

Next, we are ready to create the example.

```shell
curl -X PUT 'http://127.0.0.1:9180/apisix/admin/routes/1' \
--header 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
--header 'Content-Type: application/json' \
--data-raw '{
    "uri": "/two",
    "plugins": {
        "pipeline-request": {
            "nodes": [
                {
                    "url": "http://httpbin.org/anything"
                },
                {
                    "url": "http://127.0.0.1:9080/t1"
                }
            ]
        }
    }
}'
```

Let's test it out.

```shell
curl http://127.0.0.1:9080/two -i   
```

```text
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive
Server: APISIX/2.15.0
Date: Fri, 21 Oct 2022 15:54:04 GMT
X-Test: transformer1

{
  "ARGS": {}, 
  "DATA": "", 
  "FILES": {}, 
  "FORM": {}, 
  "HEADERS": {
    "ACCEPT": "*/*", 
    "HOST": "127.0.0.1", 
    "USER-AGENT": "CURL/7.81.0", 
    "X-AMZN-TRACE-ID": "ROOT=1-6352C09D-2E9B10DD167D95A633446254"
  }, 
  "JSON": NULL, 
  "METHOD": "GET", 
  "ORIGIN": "113.87.182.160", 
  "URL": "HTTP://127.0.0.1/ANYTHING"
}
```

You can see a fully capitalized response body and the X-Test header added by the transformer.

[Back to TOC](#table-of-contents)

## More nodes

You are free to add more entries to the nodes, and they will all be requested in turn, but note that more nodes means more time consuming and a greater probability of failure.

[Back to TOC](#table-of-contents)
