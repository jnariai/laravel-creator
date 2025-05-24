# Laravel Creator: Zero-Local PHP Installation via Docker

Effortlessly scaffold a new [Laravel](https://laravel.com/) project with nothing but Docker—**no need to install PHP, Composer, or Node.js on your local machine**. This repository provides a lightweight Bash script that uses the official Laravel installer inside a Docker container, ensuring a clean, reproducible setup every time.

## 🚀 Quick Start

Run this one-liner in your terminal to instantly start a new Laravel project:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jnariai/laravel-creator/main/laravel-creator.sh)"
```

## 🛠️ Features

- **Zero local dependencies**: No PHP, Composer, or Node.js required on your system
- **Simple usage**: Just run a single command to bootstrap your app
- **Works on macOS, Linux, and Windows with WSL**

## 🗺️ Roadmap

Planned features for upcoming releases:

- Bundled MySQL database container option
- Bundled PostgreSQL database container option
- Redis support
- Optional dedicated container for Laravel Queue
- Optional dedicated container for Laravel Reverb
- Optional dedicated container for Laravel Horizon
- Optional dedicated container for Laravel Scout

## 🧑‍💻 Contributing

Pull requests, bug reports, and feature suggestions are welcome! Please open an issue or PR if you’d like to help.

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

## 📣 Credits

Developed and maintained by [@jnariai](https://github.com/jnariai).