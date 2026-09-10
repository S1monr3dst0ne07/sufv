

use "lib/http.yap"

seq Server
{
    SOCKET, // server socket
    CONN,   // current connection socket
    REQ,    // latest request
    PATH_PREFIX,
}

fn RenderPath(srv, suffix)
{
    static 4096 ~ buffer;
    Str::Format(buffer, "%s/%s", [
        srv.Server::PATH_PREFIX,
        suffix,
    ]);

    return buffer;
}


fn SendIndexFrontend(srv)
{
    put header = HT::Create();

    put content = FS::Read("./index.html");
    put content_length = Chunk::Size(content) - 1;

    put content_length_string = Str::Copy(Str::FromIntBase(content_length, 10));
    HT::Set(header, "Content-Length", content_length_string);
    Chunk::Void(content_length_string);

    Http::Send(srv.Server::CONN, header, content, content_length);
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

fn DirTypeToStr(type)
{
    jump dir  ~ type == FS::Dir::Type::DIR;
    jump file ~ type == FS::Dir::Type::FILE;
    return "unknown";

    lab dir;  return "dir";
    lab file; return "file";
}

fn ProcessListing(srv, path)
{
    put listing_str = Dyn::Create();
    put listing_obj = FS::Dir(path);

    static (1 << 16) ~ line;
    
    put i = 0;
    lab loop;
        jump done ~ i == Dyn::Size(listing_obj);
        put dirent = Dyn::Ptr(listing_obj).i;

        Str::Format(line, "%s,%s\n", [
            DirTypeToStr(dirent.FS::Dir::Ent::TYPE),
            dirent.FS::Dir::Ent::NAME,
        ]);

        put tmp = Dyn::CreatePopulate(
            Str::Len(line),
            (1 << 16),
            line,
        );
        Dyn::Merge(listing_str, tmp);
        Chunk::Void(tmp);
        
        put i = i + 1;
        jump loop;
    lab done;


    put header = HT::Create();
    HT::Set(header, "Content-Type", "text/plain");

    Http::Send(
        srv.Server::CONN, 
        header, 
        Dyn::Ptr(listing_str), 
        Dyn::Size(listing_str),
    );
    HT::Void(header);

    Dyn::Delete(listing_str);
}

fn ProcessRequest(srv)
{
    put req = srv.Server::REQ;

    put table = req.Http::Request::PARAMS;
    put req_type_field_name = "Action";

    jump bad_req ~ Bool::Not(HT::Has(table, req_type_field_name));
    put req_type = HT::Get(table, req_type_field_name);
    put path_suffix = Http::Unescape(req.Http::Request::PATH);
    put path = RenderPath(srv, path_suffix);
    Chunk::Void(path_suffix);

    jump skip_listing  ~ Str::Diff(req_type, "Listing");  ProcessListing(srv, path); lab skip_listing;
    //jump skip_download ~ Str::Diff(req_type, "Download"); ProcessDownload(srv, path); lab skip_listing;

    jump done;

lab bad_req;
    print("bad request\n");

lab done;
}


fn main()
{
    put addr = Net::ParseAddr("0.0.0.0");
    put port = Net::HostToNetShort(5000);
    put socket = Net::Server::Init(addr, port, 10);

    put srv = Chunk::New(Server);
    put srv.Server::SOCKET = socket;

    put srv.Server::PATH_PREFIX = "./root";

    serve(srv);
}

fn serve(srv)
{
    lab loop;
        put srv.Server::CONN = Net::Server::Accept(srv.Server::SOCKET);
        put srv.Server::REQ  = Http::Recv(srv.Server::CONN);

        put method = (srv.Server::REQ).Http::Request::METHOD;
        jump route_get  ~ method == Http::MethodKind::GET;
        jump route_post ~ method == Http::MethodKind::POST;
    lab continue;

        Http::VoidReq(srv.Server::REQ);
        Net::Close(srv.Server::CONN);
    jump loop;


    lab route_get;
        SendIndexFrontend(srv);
        jump continue;

    lab route_post;
        ProcessRequest(srv);
        jump continue;
}



