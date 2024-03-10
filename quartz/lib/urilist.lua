local function parse(content)
    local uris = {}
    local meta = {}

    local lines = {}
    for s in content:gmatch("[^\r\n]+") do
        table.insert(lines, s)
    end

    local metaString = table.remove(lines, 1)
    meta.album = metaString:match("^(.+);") or "Mix"
    meta.author = metaString:match(";(.+)$") or "Multiple authors"
    repeat
        local uri = table.remove(lines, 1)
        if http.checkURL(uri) then
            table.insert(uris, uri)
        end
    until #lines <= 0

    return uris, meta
end

return {
    parse = parse,
}