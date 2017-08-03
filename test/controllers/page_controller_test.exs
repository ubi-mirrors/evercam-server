defmodule EvercamMedia.PageControllerTest do
  use EvercamMediaWeb.ConnCase

  test "GET /" do
    conn = get build_conn(), "/"
    assert conn.resp_body =~ "<body>You are being <a href=\"http://www.evercam.io\">redirected</a>.</body>"
  end
end
