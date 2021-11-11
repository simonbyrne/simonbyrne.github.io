"""
    {{posts}}

Plug in the list of blog posts contained in the `/notes/` folder.
"""
@delay function hfun_posts()
    list = readdir("notes")
    filter!(f -> endswith(f, ".md"), list)
    function date_sorter(page)
        ps  = splitext(page)[1]
        url = "/notes/$ps/"
        surl = strip(url, '/')
        return Date(pagevar(surl, :date))
    end
    sort!(list, by=date_sorter, rev=true)

    io = IOBuffer()
    write(io, """<ul class="posts">""")
    for (i, post) in enumerate(list)
        ps  = splitext(post)[1]
        url = "/notes/$ps/"
        surl = strip(url, '/')
        title = pagevar(surl, :title)
        date = Date(pagevar(surl, :date))
        if date <= today()
            write(io, """<li><i>$date</i> &nbsp; <a href="$url">$title</a>""")
        end
    end
    write(io, "</ul>")
    return String(take!(io))
end

