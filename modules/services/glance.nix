{ ... }:
{
  flake.nixosModules.glance =
    { ... }:
    {
      services.glance = {
        enable = true;
        openFirewall = true;
        settings = {
          server = {
            host = "0.0.0.0";
            port = 8080;
          };
          theme = {
            background-color = "240 13 14";
            primary-color = "51 33 68";
            contrast-multiplier = 1.2;
            negative-color = "358 100 68";
          };
          pages = [
            {
              name = "Home";
              columns = [
                {
                  size = "small";
                  widgets = [
                    { type = "calendar"; }
                    {
                      type = "weather";
                      location = "Madrid, Spain";
                    }
                  ];
                }
                {
                  size = "full";
                  widgets = [
                    {
                      type = "rss";
                      limit = 40;
                      collapse-after = 15;
                      cache = "12h";
                      feeds = [
                        {
                          url = "https://news.ycombinator.com/rss";
                          name = "hackernews";
                        }
                        {
                          url = "https://feeds.arstechnica.com/arstechnica/index/";
                          name = "arstechnica";
                        }
                      ];
                    }
                  ];
                }
                {
                  size = "full";
                  widgets = [
                    {
                      type = "group";
                      collapse-after = 15;
                      cache = "12h";
                      widgets = [
                        {
                          type = "reddit";
                          subreddit = "sre";
                        }
                        {
                          type = "reddit";
                          subreddit = "kubernetes";
                        }
                        {
                          type = "reddit";
                          subreddit = "golang";
                        }
                        {
                          type = "reddit";
                          subreddit = "unixporn";
                          show-thumbnails = true;
                        }
                      ];
                    }
                    {
                      type = "lobsters";
                      sort-by = "hot";
                      tags = [
                        "go"
                        "linux"
                        "devops"
                      ];
                      limit = 15;
                      collapse-after = 5;
                    }
                  ];
                }
              ];
            }
          ];
        };
      };
    };
}
