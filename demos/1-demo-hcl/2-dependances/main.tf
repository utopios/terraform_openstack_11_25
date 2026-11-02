resource "null_resource" "server" {
    triggers = {
        server_name = "my_server"
    }
}

resource "null_resource" "web_app" {
    depends_on = [null_resource.server]
    lifecycle {
      create_before_destroy = true
      prevent_destroy = true
    }
}