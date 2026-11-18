import { handler } from "./index.ts";
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";

Deno.test("Auth tests - missing authorization header", async () => {
  const req = new Request("http://localhost/student_update_display_name", {
    method: "POST",
    headers: new Headers(),
    body: JSON.stringify({ new_name: "Test Student" })
  });

  const response = await handler(req);
  assertEquals(response.status, 401);
  const data = await response.json();
  assertEquals(data.error, "Missing authorization header");
});

Deno.test("Auth tests - invalid authorization format (no Bearer)", async () => {
  const req = new Request("http://localhost/student_update_display_name", {
    method: "POST",
    headers: new Headers({
      "Authorization": "Basic some_token_here"
    }),
    body: JSON.stringify({ new_name: "Test Student" })
  });

  const response = await handler(req);
  assertEquals(response.status, 401);
  const data = await response.json();
  assertEquals(data.error, "Invalid authorization format");
});

Deno.test("Auth tests - invalid authorization format (empty token)", async () => {
  const req = new Request("http://localhost/student_update_display_name", {
    method: "POST",
    headers: new Headers({
      "Authorization": "Bearer   "
    }),
    body: JSON.stringify({ new_name: "Test Student" })
  });

  const response = await handler(req);
  assertEquals(response.status, 401);
  const data = await response.json();
  assertEquals(data.error, "Invalid authorization format");
});
