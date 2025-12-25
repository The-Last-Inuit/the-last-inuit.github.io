+++
title = "URL"
date = 2025-11-26
+++

Today's a fun day. Let's talk about frontend development.

One of the first things I tried to code a loooong time ago was buttons (in Visual Basic) dancing around on your screen. And if they overlapped, they would clone themselves and create a new breed of buttons. In my quite naive teenage mind, I wanted to make life. Why? Who knows... most teenagers are masturbating or making out with women, me I was playing with my computer.

Eventually, I found my way to web technology. I must confess I liked it until I met someone who was very anal about having the *right* position and pixels. Then I learned the hard truth about browsers and standardization (more like bastardization).

I did, however, enjoy learning about URLs and their parts. So, let’s create a URL manager in Rust.

Our `Cargo.toml`:

```toml
[package]
name = "murl"
version = "0.1.0"
edition = "2024"

[dependencies]
idna = "1"
percent-encoding = "2"
```

The struct is quite simple, nothing fancy. I always dislike complexity as an excuse for things to be justified:

```bash
├── src
│   ├── encoding.rs
│   ├── fragment.rs
│   ├── lib.rs
│   ├── main.rs
│   ├── murl.rs
│   ├── path.rs
│   └── query.rs
```

And a simple test of its functionality:

```rust
use murl::Murl;
use murl::Path;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut f = Murl::parse("http://www.google.com/?one=1&two=2")?;
    f.path.push("path");
    f.query.params.remove("one");
    f.query.params.set("three", Some("3"));
    assert_eq!(f.to_string(), "http://www.google.com/path?two=2&three=3");

    // Fragment path + args (hash-bang style)
    let mut f2 = Murl::parse("http://www.google.com/")?;
    let frag = f2.fragment.get_or_insert_with(Default::default);
    frag.path = Path::parse("!", false)?;
    frag.query.params.set("a", Some("dict"));
    frag.query.params.set("of", Some("args"));
    frag.separator = false;
    assert_eq!(f2.to_string(), "http://www.google.com/#!a=dict&of=args");

    Ok(())
}
```

:tada!
