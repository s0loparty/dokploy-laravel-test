# dokploy-laravel-test

Laravel application prepared for deployment through Dokploy using a prebuilt Docker image.

## Mixed Content / `http://localhost` in production

### Symptoms

- The site opens over `https`, but some requests go to `http://...`
- Browser console shows `Mixed Content`
- Generated frontend links point to `http://localhost/...`
- In `public/build/assets/*.js` you can find `http://localhost/...`

### Root cause

This project uses Laravel Wayfinder during `vite build`.

If the frontend build runs with `APP_ENV=production` and no correct runtime `APP_URL`, Laravel boots with its default fallback URL and Wayfinder can generate absolute URLs like `http://localhost/...` directly into the compiled frontend bundle.

That means the problem is already baked into `public/build`, so changing Dokploy environment variables after the image is built does not fix those links.

### Fix

The Docker build must generate Wayfinder routes in a non-production app context and clear route cache before the frontend build:

```dockerfile
RUN php artisan route:clear \
    && APP_ENV=local npm run build
```

This prevents absolute `http://localhost/...` URLs from being embedded into the built assets.

### What else is required

- Set `APP_URL` to your real production domain, for example `https://test.suetovlabs.ru`
- Trust reverse proxy headers in Laravel when running behind Dokploy / Traefik
- Rebuild and redeploy the Docker image after changing the build pipeline

### How to verify inside the container

```bash
cd /var/www/html

grep -ao 'http://localhost[^"'\''[:space:]]*' public/build/assets/*.js
php artisan tinker --execute='dump(config("app.url"));'
```

Expected result:

- `grep` should not return frontend route URLs like `http://localhost/login`
- `config("app.url")` should return your real production URL
