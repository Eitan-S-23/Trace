# Trace Update Admin

Admin UI implementation is intentionally deferred until the Worker+D1 control plane is verified.

No direct admin mutation route is exposed on the standalone Worker. During the no-custom-domain phase, mutations must be implemented behind Cloudflare Access through Pages Functions same-origin routes or an equivalent Access-protected facade.
