

use "lib/http.yap"

fn SendIndexFrontend(conn)
{
    put header = HT::Create();

    put content = FS::Read("./index.html");
    put content_length = Chunk::Size(content) - 1;

    put content_length_string = Str::Copy(Str::FromIntBase(content_length, 10));
    HT::Set(header, "Content-Length", content_length_string);
    Chunk::Void(content_length_string);

    Http::Send(conn, header, content, content_length);
    HT::Void(header);
}

fn DEAD(conn, req)
{
    put header = HT::Create();
    HT::Set(header, "Content-Type", "text/json");

    put content = "hello world";
    put content_length = Str::Len(content);

    Http::Send(conn, header, content, content_length);
    HT::Void(header);
}

fn ProcessListing(conn, path)
{
    print("listing on `%s`\n", [path]);
}

fn ProcessRequest(conn, req)
{
    put table = req.Http::Request::PARAMS;
    put req_type_field_name = "Action";

    jump bad_req ~ Bool::Not(HT::Has(table, req_type_field_name));
    put req_type = HT::Get(table, req_type_field_name);
    put path = Http::Unescape(req.Http::Request::PATH);

    jump skip_listing  ~ Str::Diff(req_type, "Listing");  ProcessListing(conn, path); lab skip_listing;
    //jump skip_download ~ Str::Diff(req_type, "Download"); ProcessDownload(conn, path); lab skip_listing;

    Chunk::Void(path);
    jump done;

lab bad_req;
    print("bad request\n");

lab done;
}


fn main()
{
    put addr = Net::ParseAddr("0.0.0.0");
    put port = Net::HostToNetShort(5000);
    put server = Net::Server::Init(addr, port, 10);

    serve(server);
}

fn serve(server)
{
    lab loop;
        put conn = Net::Server::Accept(server);
        put req = Http::Recv(conn);

        put method = req.Http::Request::METHOD;
        jump route_get  ~ method == Http::MethodKind::GET;
        jump route_post ~ method == Http::MethodKind::POST;
    lab continue;

        Http::VoidReq(req);
        Net::Close(conn);
    jump loop;


    lab route_get;
        SendIndexFrontend(conn);
        jump continue;

    lab route_post;
        ProcessRequest(conn, req);
        jump continue;
}



