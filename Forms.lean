import Forms.FormBody

/-!
# `Forms`: decoding `application/x-www-form-urlencoded` request bodies

Turns a raw request body (`title=Buy+milk`) into `(name, value)` pairs
(`Forms/FormBody.lean`'s `parseFormBody`) and provides `formField`, the
per-handler convenience most callers actually want: read the body off a
`Routing.Result` handler's `Request Body.Stream` and look up one field by
name.
-/
