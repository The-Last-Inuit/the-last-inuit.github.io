defmodule Idunnowhatiamdoing.Layouts.App do
  use Tableau.Layout

  import Temple

  def template(assigns) do
    temple do
      "<!DOCTYPE html>"

      html lang: "en" do
        head do
          link rel: "apple-touch-icon", sizes: "57x57", href: "/apple-icon-57x57.png"
          link rel: "apple-touch-icon", sizes: "60x60", href: "/apple-icon-60x60.png"
          link rel: "apple-touch-icon", sizes: "72x72", href: "/apple-icon-72x72.png"
          link rel: "apple-touch-icon", sizes: "76x76", href: "/apple-icon-76x76.png"
          link rel: "apple-touch-icon", sizes: "114x114", href: "/apple-icon-114x114.png"
          link rel: "apple-touch-icon", sizes: "120x120", href: "/apple-icon-120x120.png"
          link rel: "apple-touch-icon", sizes: "144x144", href: "/apple-icon-144x144.png"
          link rel: "apple-touch-icon", sizes: "152x152", href: "/apple-icon-152x152.png"
          link rel: "apple-touch-icon", sizes: "180x180", href: "/apple-icon-180x180.png"
          link rel: "icon", type: "image/png", sizes: "192x192", href: "/android-icon-192x192.png"
          link rel: "icon", type: "image/png", sizes: "32x32", href: "/favicon-32x32.png"
          link rel: "icon", type: "image/png", sizes: "96x96", href: "/favicon-96x96.png"
          link rel: "icon", type: "image/png", sizes: "16x16", href: "/favicon-16x16.png"
          link rel: "manifest", href: "/manifest.json"
          link rel: "stylesheet", href: "/css/site.css"
          meta charset: "utf-8"
          meta name: "msapplication-TileColor", content: "#ffffff"
          meta name: "msapplication-TileImage", content: "/ms-icon-144x144.png"
          meta name: "theme-color", content: "#ffffff"
          meta name: "viewport", content: "width=device-width, initial-scale=1"
          meta name: "description", content: "i dunno what i am doing — Software Engineering Blog"
          meta http_equiv: "X-UA-Compatible", content: "IE=edge"
          title do: "i dunno what i am doing — Software Engineering Blog"
        end

        body class: "min-h-screen bg-black text-c64ink antialiased font-mono" do
          header class: "pt-10 pb-6 border-b border-c64alt/30" do
            div class: "flex items-center justify-between gap-4" do
              a class: "group inline-flex items-center gap-3", href: "#" do
                h1 class: "text-2xl tracking-wide" do
                  "i dunno what i am doing"
                end
              end
            end
          end

          p class: "mt-3 text-sm opacity-80" do
            em do: "Software engineering à la Mexicana"
            div class: "text-xs" do
              p do
                """
                This is a very opinionated blog about software engineering. None of the following is
                #{em do: "la neta del planeta."}
                If you came here for tru tru, nah, move along.
                What we do he'a is throw ideas 'round and see what kind of desmadre they cause.
                It's messy, questionable, ilogical, and maybe illegal.
                Don't use these ideas, play with them, learn with them, steal what you find useful, and move on, carnal.
                """
              end
            end
          end

          div class: "mx-auto max-w-prose px-4 sm:px-6 lg:px-8" do
            main id: "content", class: "py-10 space-y-16" do
              render(@inner_content)
            end
          end

          footer class: "py-10 mt-12 border-t border-c64alt/30 text-xs opacity-80" do
            div do
              p style: "text-align: center;" do
                a href: "https://idunnowhatiamdoing.engineering" do
                  """
                  #{strong do: "i dunno what i am doing"}
                  by
                  """
                end

                a href: "https://github.com/n0um3n4" do
                  """
                  #{strong do: "noumena"}
                  is marked
                  """
                end

                a href: "https://creativecommons.org/publicdomain/zero/1.0/" do
                  """
                  #{strong do: "CC0 1.0 Universal"}
                  #{img src: "https://mirrors.creativecommons.org/presskit/icons/cc.svg", alt: "", style: "display: inline; max-width: 1em;max-height:1em;margin-left: .2em;"}
                  #{img src: "https://mirrors.creativecommons.org/presskit/icons/zero.svg", alt: "", style: "display: inline; max-width: 1em;max-height:1em;margin-left: .2em;"}
                  """
                end
              end
            end
          end
        end

        #if Mix.env() == :dev do
        #  c &Tableau.live_reload/1
        #end
      end
    end
  end
end
