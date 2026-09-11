

use "lib/http.yap"
use "lib/fs.yap"

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

    Http::Send(srv.Server::CONN, 200, header, content, content_length);
    HT::Void(header);
    Chunk::Void(content);
}

seq Config
{
    FILE_CHUNK = 1000000,
}

fn SendFile(srv, path)
{
    put req = srv.Server::REQ;
    put req_header = req.Http::Request::PARAMS;

    jump stream ~ HT::Has(req_header, "Range");
    jump direct;

lab stream; SendFileStream(srv, path); jump done;
lab direct; SendFileDirect(srv, path); jump done;

    lab done;
}


fn SendFileDirect(srv, path)
{
    put content = FS::Read(path);
    put content_length = Chunk::Size(content) - 1;

    static 4096 ~ content_length_string;
    Str::Format(content_length_string, "%d", [content_length]);  


    put header = HT::Create();
    HT::Set(header, "Content-Length", content_length_string);

    Http::Send(
        srv.Server::CONN,
        200,
        header,
        content,
        content_length,
    );
    HT::Void(header);
    Chunk::Void(content);
}


fn SendFileStream(srv, path)
{
    put req = srv.Server::REQ;
    put req_header = req.Http::Request::PARAMS;

    put fd = syscall(
        SYSCALL::OPEN,
        FS::ConvertPath(path),
        FS::ENUM::MODE::RDONLY, // read only!
        0,
    );
    jump file_not_found ~ Sys::Error(fd);

    put full_content_length = FS::Sys::Size(fd);

    put ptr = HT::Get(req_header, "Range");
    put ptr = Str::Token(ptr, '=');
    put offset_string = ptr;
    put ptr = Str::Token(ptr, '-');

    put offset = Str::ToInt(offset_string);

    static Config::FILE_CHUNK ~ bchunk;
    static Config::FILE_CHUNK ~ qchunk;

    syscall(SYSCALL::LSEEK, fd, offset, FS::Seek::Mode::SEEK_SET);
    put bytes_read = syscall(
        SYSCALL::READ,
        fd,
        bchunk,
        Config::FILE_CHUNK,
    );
    Mem::FromBytes(qchunk, bchunk, bytes_read);



    put resp_header = HT::Create();

    static 4096 ~ content_length_string;
    Str::Format(content_length_string, "%d", [bytes_read]);  
    HT::Set(resp_header, "Content-Length", content_length_string);

    static 4096 ~ content_range_string;
    Str::Format(content_range_string, "bytes %d-%d/%d", [
        offset,
        (offset + bytes_read) - 1,
        full_content_length,
    ]);  
    HT::Set(resp_header, "Content-Range", content_range_string);

    Http::Send(
        srv.Server::CONN, 
        206, // partial content
        resp_header, 
        qchunk,
        bytes_read,
    );
    HT::Void(resp_header);

lab file_not_found;
}



fn DirTypeToStr(type)
{
    jump dir  ~ type == FS::Dir::Type::DIR;
    jump file ~ type == FS::Dir::Type::FILE;
    return "unknown";

    lab dir;  return "dir";
    lab file; return "file";
}

fn ProcessCheckDir(srv, path)
{
    put header = HT::Create();
    HT::Set(header, "Content-Type", "text/plain");

    jump yes ~ FS::IsDir(path); jump no;

    lab yes; put resp = "yes"; jump go;
    lab no;  put resp = "no"; jump go;

lab go;
    Http::Send(
        srv.Server::CONN, 
        200,
        header, 
        resp, 
        Str::Len(resp),
    );
    HT::Void(header);
}

fn ProcessListing(srv, path)
{
    put listing_str = Dyn::Create();
    put listing_obj = FS::Dir(path);
    jump not_a_dir ~ listing_obj == Mem::NULL;

    static (1 << 16) ~ line;
    
    put i = 0;
    lab loop;
        jump done ~ i == Dyn::Size(listing_obj);
        put dirent = Dyn::Ptr(listing_obj).i;

        put subdir_name = dirent.FS::Dir::Ent::NAME;

        Str::Format(line, "%s,%s\n", [
            DirTypeToStr(dirent.FS::Dir::Ent::TYPE),
            subdir_name,
        ]);

        put tmp = Dyn::CreatePopulate(
            Str::Len(line),
            (1 << 16),
            line,
        );
        Dyn::Merge(listing_str, tmp);
        Chunk::Void(tmp);

        Chunk::Void(dirent);
        Chunk::Void(subdir_name);
        
        put i = i + 1;
        jump loop;
    lab done;
    Dyn::Delete(listing_obj);

    put header = HT::Create();
    HT::Set(header, "Content-Type", "text/plain");

    Http::Send(
        srv.Server::CONN, 
        200,
        header, 
        Dyn::Ptr(listing_str), 
        Dyn::Size(listing_str),
    );
    HT::Void(header);
    Dyn::Delete(listing_str);

lab not_a_dir;
}

fn ProcessRequest(srv, path)
{
    put req = srv.Server::REQ;

    put table = req.Http::Request::PARAMS;
    put req_type_field_name = "Action";

    jump bad_req ~ Bool::Not(HT::Has(table, req_type_field_name));
    put req_type = HT::Get(table, req_type_field_name);

    jump skip_listing    ~ Str::Diff(req_type, "Listing");  ProcessListing(srv, path);  lab skip_listing;
    jump skip_dir_check  ~ Str::Diff(req_type, "CheckDir"); ProcessCheckDir(srv, path); lab skip_dir_check;

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

    //put srv.Server::PATH_PREFIX = "./root";
    put srv.Server::PATH_PREFIX = FS::Read("prefix.txt");
    print("path prefix: `%s`\n", [srv.Server::PATH_PREFIX]);

    serve(srv);
}

fn serve(srv)
{
    lab loop;
        put srv.Server::CONN = Net::Server::Accept(srv.Server::SOCKET);
        put req = Http::Recv(srv.Server::CONN);
        put srv.Server::REQ = req;

        put path_suffix = Http::Unescape(req.Http::Request::PATH);
        put path = RenderPath(srv, path_suffix);
        Chunk::Void(path_suffix);

        put method = req.Http::Request::METHOD;
        jump route_get  ~ method == Http::MethodKind::GET;
        jump route_post ~ method == Http::MethodKind::POST;
    lab continue;

        Http::VoidReq(srv.Server::REQ);
        Net::Close(srv.Server::CONN);
    jump loop;

    lab route_get;
        put last_char_ptr = path : (Str::Len(path) - 1);
        jump send_file ~ (last_char_ptr.0) == '&';

        SendIndexFrontend(srv);
        jump continue;

    lab send_file;
        put last_char_ptr.0 = '\0';
        SendFile(srv, path);
        jump continue;

    lab route_post;
        ProcessRequest(srv, path);
        jump continue;
}



