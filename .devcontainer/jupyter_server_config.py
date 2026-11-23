import os

c = get_config()

codespace_name = os.environ.get("CODESPACE_NAME")
if codespace_name:
    # The editor uses github.dev; forwarded ports use app.github.dev instead.
    editor_origin = f"https://{codespace_name}.github.dev"
    # The Codespaces editor embeds Jupyter from a different origin.
    # Limit embedding and cross-origin access to this codespace's editor.
    c.ServerApp.allow_origin = editor_origin
    c.ServerApp.cookie_options = {"SameSite": "None", "Secure": True}
    c.ServerApp.tornado_settings = {
        "headers": {
            "Content-Security-Policy": f"frame-ancestors 'self' {editor_origin}",
            "Access-Control-Allow-Headers": (
                "accept, content-type, authorization, x-xsrftoken, x-github-token"
            ),
        }
    }
