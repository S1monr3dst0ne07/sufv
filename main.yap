

use "lib/http.yap"

fn SendIndex(conn)
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

fn SendDictory(conn, req)
{
    put header = HT::Create();
    HT::Set(header, "Content-Type", "text/json");

    put content = "hello world";
    put content_length = Str::Len(content);

    Http::Send(conn, header, content, content_length);
    HT::Void(header);
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
        SendIndex(conn);
        jump continue;

    lab route_post;
        SendDictory(conn, req);
        jump continue;
}



