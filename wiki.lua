local orbit = require("orbit")
local cosmo = require("cosmo")
local luasql = require("luasql.mysql")
local env = luasql.mysql()

local wiki = orbit.new()

wiki.mapper = {
  default = true,
  logging = true,
  conn = env:connect("luawiki", "root")
}

wiki.pages = wiki:model("pages")

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
  return wiki.layout(wiki.render_show({page = page}))
end

wiki:dispatch_get(wiki.show, "/pages/(%d+)")

function wiki.new(web)
  local page = wiki.pages:new()
  return wiki.layout(wiki.render_new({page = page}))
end

wiki:dispatch_get(wiki.new, "/pages/new")

function wiki.create(web)
  local page = wiki.pages:new(web.POST)
  page:save()
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
  for k,v in pairs(web.POST) do
    if k ~= "id" then
      page[k] = v
    end
  end
  page:save()
  return web:redirect("/pages")
end

wiki:dispatch_post(wiki.update, "/pages/(%d+)")

function wiki.delete(web, page_id)
  local page = wiki.pages:find(tonumber(page_id))
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
  Page id $(page.id) has the title "$(page.title)".<br /><br />
  <a href="/pages/$(page.id)/edit">Edit page</a>
  <form action="/pages/$(page.id)/delete" method="post">
  <input type="submit" value="Delete" />
  </form>
]]

wiki.render_new = cosmo.compile[[
  <form action="/pages" method="post">
  <label>Title: <input name="title" /></label>
  <input type="submit" />
  </form>
]]

wiki.render_edit = cosmo.compile[[
  <form action="/pages/$(page.id)" method="post">
  <label>Title: <input name="title" value="$(page.title)" /></label>
  <input type="submit" />
  </form>
]]

return wiki.run
