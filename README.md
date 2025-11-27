Usage:
  cider <cidr>                            Show CIDR info
  cider next <cidr> [--prefix <len>]      Calculate next subnet
  cider transform <cidr> --prefix <len>   Resize to different prefix

Example:
  cider 192.168.1.0/24
  cider next 192.168.1.0/24
  cider next 192.168.1.0/24 --prefix 27
  cider transform 192.168.1.0/24 --prefix 27