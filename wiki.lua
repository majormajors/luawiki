discount = require("discount")
local orbit = require("orbit")
local cosmo = require("cosmo")
local luasql = require("luasql.mysql")
local env = luasql.mysql()

function escape_html(str)
  return str:gsub("<","&lt;"):gsub(">","&gt;")
end

local wiki = orbit.new()

wiki.mapper = {
  default = true,
  logging = true,
  conn = env:connect("luawiki", "root")
}

wiki.pages = wiki:model("pages")
wiki.revisions = wiki:model("revisions")

function wiki.pages:revisions()
  return wiki.revisions:find_all("page_id = ?", {self.id, order = "created_at DESC"})
end

function wiki.pages:current_revision()
  return wiki.revisions:find_first("page_id = ?", {self.id, order = "created_at DESC"})
end

wiki:dispatch_get(function(web)
  return web:redirect("/pages")
end, "/")

wiki:dispatch_get(function(web, filename)
  return wiki:serve_static(web, "public" .. filename)
end, "/.+%.css", "/.+%.jpg", "/.+%.png", "/.+%.gif", "/.+%.js")

function wiki.index(web)
  local page_list = wiki.pages:find_all()
  return wiki.layout(wiki.render_index({ pages = page_list }))
end

wiki:dispatch_get(wiki.index, "/pages")

function wiki.show(web, page_id)
  local page = wiki.pages:find(tonumber(page_id))
  return wiki.layout(wiki.render_show({
    page = page,
    body = discount(page:current_revision().body),
    revisions = page:revisions()
  }))
end

wiki:dispatch_get(wiki.show, "/pages/(%d+)")

function wiki.show_revision(web, page_id, rev_id)
  local revision = wiki.revisions:find(tonumber(rev_id))
  return wiki.layout(wiki.render_show_revision({ revision = revision }))
end

wiki:dispatch_get(wiki.show_revision, "/pages/(%d+)/revisions/(%d+)")

function wiki.new(web)
  local page = wiki.pages:new()
  return wiki.layout(wiki.render_new({page = page}))
end

wiki:dispatch_get(wiki.new, "/pages/new")

function wiki.create(web)
  local page = wiki.pages:new()
  page.title = web.POST.title
  page:save()
  local revision = wiki.revisions:new()
  revision.page_id = page.id
  revision.body = escape_html(web.POST.body)
  revision:save()
  return web:redirect("/pages")
end

wiki:dispatch_post(wiki.create, "/pages")

function wiki.edit(web, page_id)
  local page = wiki.pages:find(tonumber(page_id))
  return wiki.layout(wiki.render_edit({page = page}))
end

wiki:dispatch_get(wiki.edit, "/pages/(%d+)/edit")

function wiki.update(web, page_id)
  local page =  wiki.pages:find(tonumber(page_id))
  page.title = web.POST.title
  local revision = wiki.revisions:new()
  revision.body = web.POST.body
  revision.page_id = page.id
  revision:save()
  return web:redirect("/pages")
end

wiki:dispatch_post(wiki.update, "/pages/(%d+)")

function wiki.delete(web, page_id)
  local page = wiki.pages:find(tonumber(page_id))
  for _, rev in ipairs(page:revisions()) do
    rev:delete()
  end
  page:delete()
  return web:redirect("/pages")
end

wiki:dispatch_post(wiki.delete, "/pages/(%d+)/delete")

function wiki.layout(inner_html)
  return "<!DOCTYPE html>\n" .. html {
    head {
      title("waf"),
      [[<link rel="stylesheet" href="/style.css" />]]
    },
    body { inner_html }
  }
end

orbit.htmlify(wiki, "layout")

wiki.render_index = cosmo.compile[[
  <h1>Wiki pages</h1>
  <ul>
  $pages[=[<li><a href="/pages/$id">$title</a></li>]=]
  </ul>
  <a href="/pages/new">New page</a>
]]

wiki.render_show = cosmo.compile[[
  <h1>$(page.title)</h1>
  <blockquote style="background: lightgray; border: 1px solid black; padding: 5px">
  $body
  </blockquote>
  <a href="/pages/$(page.id)/edit">Edit page</a>
  <form action="/pages/$(page.id)/delete" method="post">
  <input type="submit" value="Delete" />
  </form>
  <h3>Revisions</h3>
  <ul>
  $revisions[=[<li><a href="/pages/$(page.id)/revisions/$id">$created_at</a></li>]=]
  </ul>
]]

wiki.render_show_revision = cosmo.compile[[
  <pre style="background: lightgray; border: 1px solid black; padding: 5px">$(revision.body)</pre>
]]

wiki.render_new = cosmo.compile[[
  <form action="/pages" method="post">
  <label>Title: <input name="title" /></label><br />
  Body:<br />
  <textarea name="body"></textarea>
  <input type="submit" />
  </form>
]]

wiki.render_edit = cosmo.compile[[
  <form action="/pages/$(page.id)" method="post">
  <label>Title: <input name="title" value="$(page.title)" /></label><br />
  Body:<br />
  <textarea name="body">$(page:current_revision().body)</textarea>
  <input type="submit" />
  </form>
]]

return wiki.run
