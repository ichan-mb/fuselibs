self = this;
(function (self) {
	"use strict";


	// Ensure URLSearchParams is available
	if (!self.URLSearchParams) {
		throw new Error("URLSearchParams polyfill is required for URL polyfill");
	}

	// Default ports for common protocols
	const DEFAULT_PORTS = {
		"ftp:": "21",
		"http:": "80",
		"https:": "443",
		"ws:": "80",
		"wss:": "443",
	};

	// Valid protocols (scheme names)
	const VALID_PROTOCOLS = /^[a-z][a-z0-9+.-]*:$/i;

	// Helper function to normalize protocol
	function normalizeProtocol(protocol) {
		if (typeof protocol !== "string") return "";
		protocol = protocol.toLowerCase();
		if (!protocol.endsWith(":")) {
			protocol += ":";
		}
		return VALID_PROTOCOLS.test(protocol) ? protocol : "";
	}

	// Helper function to normalize port
	function normalizePort(port, protocol) {
		if (!port || port === "" || port === "0") {
			return "";
		}

		const portNum = parseInt(port, 10);
		if (isNaN(portNum) || portNum < 0 || portNum > 65535) {
			return "";
		}

		const portStr = String(portNum);

		// Return empty string if it's the default port for the protocol
		if (DEFAULT_PORTS[protocol] === portStr) {
			return "";
		}

		return portStr;
	}

	// Helper function to normalize pathname
	function normalizePathname(pathname) {
		if (typeof pathname !== "string") {
			return "/";
		}

		// Ensure pathname starts with '/'
		if (!pathname.startsWith("/")) {
			pathname = "/" + pathname;
		}

		// Resolve . and .. segments
		const segments = pathname.split("/");
		const resolved = [];

		for (let i = 0; i < segments.length; i++) {
			const segment = segments[i];

			if (segment === "." || segment === "") {
				if (i === segments.length - 1) {
					// Keep trailing slash for paths ending with /. or //
					continue;
				}
			} else if (segment === "..") {
				if (resolved.length > 0 && resolved[resolved.length - 1] !== "..") {
					resolved.pop();
				}
			} else {
				resolved.push(segment);
			}
		}

		let result = "/" + resolved.join("/");

		// Preserve trailing slash if original had one
		if (pathname.endsWith("/") && !result.endsWith("/") && result !== "/") {
			result += "/";
		}

		return result;
	}

	// Helper function to resolve relative URLs
	function resolveURL(url, base) {
		if (!base) {
			throw new TypeError("Invalid base URL");
		}

		// Parse base URL
		const baseURL = typeof base === "string" ? new self.URL(base) : base;

		// If url is absolute, return it as-is
		if (/^[a-z][a-z0-9+.-]*:/i.test(url)) {
			return url;
		}

		// Handle protocol-relative URLs
		if (url.startsWith("//")) {
			return baseURL.protocol + url;
		}

		// Handle absolute paths
		if (url.startsWith("/")) {
			return baseURL.protocol + "//" + baseURL.host + url;
		}

		// Handle relative paths
		let basePath = baseURL.pathname;
		if (!basePath.endsWith("/")) {
			// Remove filename from base path
			const lastSlash = basePath.lastIndexOf("/");
			basePath = basePath.substring(0, lastSlash + 1);
		}

		return baseURL.protocol + "//" + baseURL.host + basePath + url;
	}

	// Parse URL string into components
	function parseURL(url) {
		// Basic URL regex pattern
		const urlPattern =
			/^(?:([^:/?#]+):)?(\/\/)?([^/?#]*)?([^?#]*)(\?[^#]*)?(#.*)?$/;
		const match = url.match(urlPattern);

		if (!match) {
			throw new TypeError("Invalid URL: " + url);
		}

		const [, protocol, slashes, authority, pathname, search, hash] = match;

		// Parse authority (user:pass@host:port)
		let username = "";
		let password = "";
		let hostname = "";
		let port = "";

		if (authority) {
			const authorityPattern =
				/^(?:([^:@]*)(?::([^@]*))?@)?([^:]+)(?::(\d+))?$/;
			const authMatch = authority.match(authorityPattern);

			if (authMatch) {
				[, username, password, hostname, port] = authMatch;
				username = username || "";
				password = password || "";
				hostname = hostname || "";
				port = port || "";
			} else {
				hostname = authority;
			}
		}

		return {
			protocol: protocol ? protocol.toLowerCase() + ":" : "",
			username: username ? decodeURIComponent(username) : "",
			password: password ? decodeURIComponent(password) : "",
			hostname: hostname ? hostname.toLowerCase() : "",
			port: port || "",
			pathname: pathname || "/",
			search: search || "",
			hash: hash || "",
		};
	}

	// URL constructor
	self.URL = function URL(url, base) {
		if (arguments.length === 0) {
			throw new TypeError("URL constructor requires at least 1 argument");
		}

		url = String(url);

		// Resolve relative URLs
		if (base !== undefined) {
			url = resolveURL(url, base);
		}

		// Parse the URL
		const parsed = parseURL(url);

		// Validate required components
		if (!parsed.protocol) {
			throw new TypeError("Invalid URL: missing protocol");
		}

		// Private properties
		let _protocol = normalizeProtocol(parsed.protocol);
		let _username = parsed.username;
		let _password = parsed.password;
		let _hostname = parsed.hostname;
		let _port = normalizePort(parsed.port, _protocol);
		let _pathname = normalizePathname(parsed.pathname);
		let _search = parsed.search;
		let _hash = parsed.hash;
		let _searchParams = new self.URLSearchParams(_search);

		// Update search when searchParams changes
		const updateSearch = () => {
			const searchString = _searchParams.toString();
			_search = searchString ? "?" + searchString : "";
		};

		// Override searchParams methods to keep URL in sync
		const originalAppend = _searchParams.append;
		_searchParams.append = function (name, value) {
			originalAppend.call(this, name, value);
			updateSearch();
		};

		const originalSet = _searchParams.set;
		_searchParams.set = function (name, value) {
			originalSet.call(this, name, value);
			updateSearch();
		};

		const originalDelete = _searchParams.delete;
		_searchParams.delete = function (name) {
			originalDelete.call(this, name);
			updateSearch();
		};

		const originalSort = _searchParams.sort;
		_searchParams.sort = function () {
			originalSort.call(this);
			updateSearch();
		};

		// Protocol property
		Object.defineProperty(this, "protocol", {
			get: () => _protocol,
			set: (value) => {
				const normalized = normalizeProtocol(value);
				if (normalized) {
					_protocol = normalized;
					_port = normalizePort(_port, _protocol);
				}
			},
			enumerable: true,
			configurable: true,
		});

		// Username property
		Object.defineProperty(this, "username", {
			get: () => _username,
			set: (value) => {
				_username = String(value);
			},
			enumerable: true,
			configurable: true,
		});

		// Password property
		Object.defineProperty(this, "password", {
			get: () => _password,
			set: (value) => {
				_password = String(value);
			},
			enumerable: true,
			configurable: true,
		});

		// Hostname property
		Object.defineProperty(this, "hostname", {
			get: () => _hostname,
			set: (value) => {
				_hostname = String(value).toLowerCase();
			},
			enumerable: true,
			configurable: true,
		});

		// Port property
		Object.defineProperty(this, "port", {
			get: () => _port,
			set: (value) => {
				_port = normalizePort(value, _protocol);
			},
			enumerable: true,
			configurable: true,
		});

		// Host property (hostname:port)
		Object.defineProperty(this, "host", {
			get: () => (_port ? _hostname + ":" + _port : _hostname),
			set: (value) => {
				const hostValue = String(value);
				const colonIndex = hostValue.lastIndexOf(":");

				if (colonIndex === -1) {
					this.hostname = hostValue;
					this.port = "";
				} else {
					this.hostname = hostValue.substring(0, colonIndex);
					this.port = hostValue.substring(colonIndex + 1);
				}
			},
			enumerable: true,
			configurable: true,
		});

		// Pathname property
		Object.defineProperty(this, "pathname", {
			get: () => _pathname,
			set: (value) => {
				_pathname = normalizePathname(String(value));
			},
			enumerable: true,
			configurable: true,
		});

		// Search property
		Object.defineProperty(this, "search", {
			get: () => _search,
			set: (value) => {
				const searchValue = String(value);
				_search =
					searchValue && !searchValue.startsWith("?")
						? "?" + searchValue
						: searchValue;
				_searchParams = new self.URLSearchParams(_search);

				// Re-bind the override methods
				const originalAppend = _searchParams.append;
				_searchParams.append = function (name, value) {
					originalAppend.call(this, name, value);
					updateSearch();
				};

				const originalSet = _searchParams.set;
				_searchParams.set = function (name, value) {
					originalSet.call(this, name, value);
					updateSearch();
				};

				const originalDelete = _searchParams.delete;
				_searchParams.delete = function (name) {
					originalDelete.call(this, name);
					updateSearch();
				};

				const originalSort = _searchParams.sort;
				_searchParams.sort = function () {
					originalSort.call(this);
					updateSearch();
				};
			},
			enumerable: true,
			configurable: true,
		});

		// Hash property
		Object.defineProperty(this, "hash", {
			get: () => _hash,
			set: (value) => {
				const hashValue = String(value);
				_hash =
					hashValue && !hashValue.startsWith("#") ? "#" + hashValue : hashValue;
			},
			enumerable: true,
			configurable: true,
		});

		// SearchParams property
		Object.defineProperty(this, "searchParams", {
			get: () => _searchParams,
			enumerable: true,
			configurable: true,
		});

		// Origin property (read-only)
		Object.defineProperty(this, "origin", {
			get: () => {
				if (_protocol === "file:") {
					return "null";
				}
				return _protocol + "//" + this.host;
			},
			enumerable: true,
			configurable: true,
		});

		// Href property
		Object.defineProperty(this, "href", {
			get: () => {
				let result = _protocol + "//";

				if (_username || _password) {
					if (_username) {
						result += encodeURIComponent(_username);
					}
					if (_password) {
						result += ":" + encodeURIComponent(_password);
					}
					result += "@";
				}

				result += _hostname;

				if (_port) {
					result += ":" + _port;
				}

				result += _pathname + _search + _hash;

				return result;
			},
			set: (value) => {
				const newURL = new self.URL(String(value));
				_protocol = newURL.protocol;
				_username = newURL.username;
				_password = newURL.password;
				_hostname = newURL.hostname;
				_port = newURL.port;
				_pathname = newURL.pathname;
				_search = newURL.search;
				_hash = newURL.hash;

				// Update searchParams
				this.search = _search;
			},
			enumerable: true,
			configurable: true,
		});

		// ToString method
		this.toString = () => this.href;

		// ToJSON method
		this.toJSON = () => this.href;
	};

	// Static methods and properties
	self.URL.createObjectURL =
		self.URL.createObjectURL ||
		function (blob) {
			if (!blob || typeof blob !== "object") {
				throw new TypeError(
					"Failed to execute 'createObjectURL' on 'URL': parameter 1 is not of type 'Blob'.",
				);
			}

			// Simple blob URL generation
			const id = Math.random().toString(36).substring(2, 15);
			return (
				"blob:" + (self.location ? self.location.origin : "null") + "/" + id
			);
		};

	self.URL.revokeObjectURL =
		self.URL.revokeObjectURL ||
		function (url) {
			// Simple revoke implementation
			return;
		};

	// Mark as polyfill
	self.URL.polyfill = true;
})(typeof self !== "undefined" ? self : this);
