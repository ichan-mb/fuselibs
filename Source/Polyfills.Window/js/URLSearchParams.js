self = this;
(function (self) {
	"use strict";

	// Don't override native URLSearchParams if it exists and works properly
	if (self.URLSearchParams && self.URLSearchParams.prototype.entries) {
		try {
			const test = new self.URLSearchParams("a=1&b=2");
			if (test.get("a") === "1" && test.get("b") === "2") {
				return; // Native URLSearchParams works fine
			}
		} catch (e) {
			// Native URLSearchParams is broken, continue with polyfill
		}
	}

	// Helper function to decode URL component with proper error handling
	function safeDecodeURIComponent(str) {
		try {
			return decodeURIComponent(str);
		} catch (e) {
			return str; // Return original string if decoding fails
		}
	}

	// Helper function to encode URL component
	function safeEncodeURIComponent(str) {
		return encodeURIComponent(str).replace(
			/[!'()*]/g,
			function (c) {
				return "%" + c.charCodeAt(0).toString(16).toUpperCase();
			}
		);
	}

	// Parse query string into array of [name, value] pairs
	function parseQueryString(query) {
		const pairs = [];

		if (typeof query !== "string") {
			return pairs;
		}

		// Remove leading '?' if present
		query = query.replace(/^\?/, "");

		if (query.length === 0) {
			return pairs;
		}

		// Split by '&' and process each pair
		const parts = query.split("&");
		for (let i = 0; i < parts.length; i++) {
			const part = parts[i];
			if (part.length === 0) continue;

			const equalIndex = part.indexOf("=");
			let name, value;

			if (equalIndex === -1) {
				// No '=' found, treat entire part as name with empty value
				name = part;
				value = "";
			} else {
				name = part.substring(0, equalIndex);
				value = part.substring(equalIndex + 1);
			}

			// Replace '+' with space and decode
			name = safeDecodeURIComponent(name.replace(/\+/g, " "));
			value = safeDecodeURIComponent(value.replace(/\+/g, " "));

			pairs.push([name, value]);
		}

		return pairs;
	}

	// Serialize pairs back to query string
	function serializePairs(pairs) {
		const parts = [];
		for (let i = 0; i < pairs.length; i++) {
			const pair = pairs[i];
			const name = safeEncodeURIComponent(pair[0]).replace(/%20/g, "+");
			const value = safeEncodeURIComponent(pair[1]).replace(/%20/g, "+");
			parts.push(name + "=" + value);
		}
		return parts.join("&");
	}

	// URLSearchParams constructor
	self.URLSearchParams = function URLSearchParams(init) {
		this._pairs = [];

		// Handle different initialization types
		if (init !== undefined && init !== null) {
			if (typeof init === "string") {
				this._pairs = parseQueryString(init);
			} else if (Array.isArray(init)) {
				// Array of [name, value] pairs
				for (let i = 0; i < init.length; i++) {
					const item = init[i];
					if (Array.isArray(item) && item.length >= 2) {
						this._pairs.push([String(item[0]), String(item[1])]);
					} else {
						throw new TypeError("Invalid URLSearchParams init: array items must be [name, value] pairs");
					}
				}
			} else if (typeof init === "object") {
				// Object with string keys
				for (const key in init) {
					if (init.hasOwnProperty(key)) {
						this._pairs.push([String(key), String(init[key])]);
					}
				}
			} else {
				throw new TypeError("Invalid URLSearchParams init type");
			}
		}

		// Append method
		this.append = function (name, value) {
			this._pairs.push([String(name), String(value)]);
		};

		// Set method (replaces all existing entries with same name)
		this.set = function (name, value) {
			name = String(name);
			value = String(value);

			let found = false;
			const newPairs = [];

			for (let i = 0; i < this._pairs.length; i++) {
				const pair = this._pairs[i];
				if (pair[0] === name) {
					if (!found) {
						// Replace first occurrence
						newPairs.push([name, value]);
						found = true;
					}
					// Skip subsequent occurrences (effectively removing them)
				} else {
					newPairs.push(pair);
				}
			}

			if (!found) {
				// Name not found, append new entry
				newPairs.push([name, value]);
			}

			this._pairs = newPairs;
		};

		// Get method (returns first value for name)
		this.get = function (name) {
			name = String(name);
			for (let i = 0; i < this._pairs.length; i++) {
				const pair = this._pairs[i];
				if (pair[0] === name) {
					return pair[1];
				}
			}
			return null;
		};

		// GetAll method (returns all values for name)
		this.getAll = function (name) {
			name = String(name);
			const values = [];
			for (let i = 0; i < this._pairs.length; i++) {
				const pair = this._pairs[i];
				if (pair[0] === name) {
					values.push(pair[1]);
				}
			}
			return values;
		};

		// Has method
		this.has = function (name) {
			name = String(name);
			for (let i = 0; i < this._pairs.length; i++) {
				if (this._pairs[i][0] === name) {
					return true;
				}
			}
			return false;
		};

		// Delete method
		this.delete = function (name) {
			name = String(name);
			this._pairs = this._pairs.filter(function (pair) {
				return pair[0] !== name;
			});
		};

		// Sort method
		this.sort = function () {
			this._pairs.sort(function (a, b) {
				if (a[0] < b[0]) return -1;
				if (a[0] > b[0]) return 1;
				if (a[1] < b[1]) return -1;
				if (a[1] > b[1]) return 1;
				return 0;
			});
		};

		// ToString method
		this.toString = function () {
			return serializePairs(this._pairs);
		};

		// ForEach method
		this.forEach = function (callback, thisArg) {
			if (typeof callback !== "function") {
				throw new TypeError("Callback must be a function");
			}

			for (let i = 0; i < this._pairs.length; i++) {
				const pair = this._pairs[i];
				callback.call(thisArg, pair[1], pair[0], this);
			}
		};

		// Keys iterator
		this.keys = function () {
			const keys = this._pairs.map(function (pair) {
				return pair[0];
			});
			let index = 0;

			const iterator = {
				next: function () {
					if (index < keys.length) {
						return { value: keys[index++], done: false };
					}
					return { done: true };
				}
			};

			// Add Symbol.iterator if available
			if (typeof Symbol !== "undefined" && Symbol.iterator) {
				iterator[Symbol.iterator] = function () {
					return this;
				};
			}

			return iterator;
		};

		// Values iterator
		this.values = function () {
			const values = this._pairs.map(function (pair) {
				return pair[1];
			});
			let index = 0;

			const iterator = {
				next: function () {
					if (index < values.length) {
						return { value: values[index++], done: false };
					}
					return { done: true };
				}
			};

			// Add Symbol.iterator if available
			if (typeof Symbol !== "undefined" && Symbol.iterator) {
				iterator[Symbol.iterator] = function () {
					return this;
				};
			}

			return iterator;
		};

		// Entries iterator
		this.entries = function () {
			const pairs = this._pairs.slice(); // Copy the array
			let index = 0;

			const iterator = {
				next: function () {
					if (index < pairs.length) {
						return { value: [pairs[index][0], pairs[index++][1]], done: false };
					}
					return { done: true };
				}
			};

			// Add Symbol.iterator if available
			if (typeof Symbol !== "undefined" && Symbol.iterator) {
				iterator[Symbol.iterator] = function () {
					return this;
				};
			}

			return iterator;
		};

		// Make URLSearchParams itself iterable (defaults to entries)
		if (typeof Symbol !== "undefined" && Symbol.iterator) {
			this[Symbol.iterator] = this.entries;
		}
	};

	// Static method to check if object is URLSearchParams
	self.URLSearchParams.prototype.constructor = self.URLSearchParams;

	// Mark as polyfill
	self.URLSearchParams.polyfill = true;

})(typeof self !== "undefined" ? self : this);
