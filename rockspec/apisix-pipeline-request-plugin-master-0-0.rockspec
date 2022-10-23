package = "apisix-pipeline-request-plugin-master"
version = "0-0"
source = {
    url = "git+https://github.com/bzp2010/apisix-pipeline-request-plugin",
    branch = "main",
}

description = {
    summary = "A plugin that implements pipeline requests (or chained requests) for APISIX",
    homepage = "https://github.com/bzp2010/apisix-pipeline-request-plugin",
    license = "Apache License 2.0",
}

dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      ["apisix.plugins.pipeline-request"] = "apisix/plugins/pipeline-request.lua"
   }
}
