# Open WebUI

Provides a rich-feature web interface for LLM models.

## Prerequisites

### API Token

Set up an OpenAI account (or other compatible services) and get an API token. The API token can be provided inside the app by admin account.

### Docker Volume

To prevent data loss, consider creating an external docker volume. An external docker volume won't be deleted even if you removed the docker compose service.

To specify the external volume in docker compose, we added the additional key value pair `external: true` to the volume block:

```yml
volumes:
  open-webui:
    external: true
```

### Environment Variables

We can provide additional environment variables to configure the app. Some example env vars are provided in the [example.open_webui.env](./example.open_webui.env) file.
