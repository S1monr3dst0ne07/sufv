
# SUFV (Simple User-friendly File Viewer)

Sufv lets you view and browse a directory from the browser.
It is intended to run on a server, which is already
serving some kind of shared directory.

The backend `main.yap` is written in YASCL and
facilitates the file stream and directory listing.
It supports whole-file downloads as well as HTTP Range requests
to download partial content.

The frontend `index.html` is served by the backend upon
request by the browser, given any path. To access the
actual file, the frontend appends an ampersand to the path.
Users can also do this to download files directly.

The serve directory is configured by the `prefix.txt`
file, which contains the path prefixed, which the server
prepends to any file or directory requests.

### Warning
This service does **NOT** implement any
safety or security features. It is intended
for local / infranet use only.

