#r "System.Net.Http"

open System.Net
open System.Net.Http

let Run(req: HttpRequestMessage) =
    async {
        return req.CreateResponse(HttpStatusCode.OK, "Hello World from an F# Azure Function");
    } |> Async.RunSynchronously