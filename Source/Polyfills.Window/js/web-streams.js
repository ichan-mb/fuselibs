/**
 * Web Streams API Polyfill for Fuse
 *
 * Comprehensive implementation of the Web Streams API including:
 * - ReadableStream with full controller support
 * - WritableStream with backpressure handling
 * - TransformStream for stream transformation
 * - Utility functions and helpers
 *
 * Based on the Streams Standard:
 * https://streams.spec.whatwg.org/
 *
 * @preserve-header
 */

(function (self) {
	"use strict";

	// Check for native implementation
	var nativeReadableStream = self.ReadableStream;
	var nativeWritableStream = self.WritableStream;
	var nativeTransformStream = self.TransformStream;

	// Feature detection
	var support = {
		readableStream: typeof nativeReadableStream === "function",
		writableStream: typeof nativeWritableStream === "function",
		transformStream: typeof nativeTransformStream === "function",
		asyncIterator: "Symbol" in self && "asyncIterator" in Symbol,
		iterator: "Symbol" in self && "iterator" in Symbol,
	};

	// Utility functions
	function isFunction(fn) {
		return typeof fn === "function";
	}

	function isObject(obj) {
		return obj !== null && typeof obj === "object";
	}

	function promiseResolve(value) {
		return Promise.resolve(value);
	}

	function promiseReject(reason) {
		return Promise.reject(reason);
	}

	function validateAndNormalizeHighWaterMark(highWaterMark) {
		highWaterMark = Number(highWaterMark);
		if (Number.isNaN(highWaterMark) || highWaterMark < 0) {
			throw new RangeError("highWaterMark must be a non-negative number");
		}
		return highWaterMark;
	}

	function validateAndNormalizeQueuingStrategy(strategy, defaultSize) {
		if (strategy === undefined) {
			return { highWaterMark: 1, size: defaultSize };
		}

		if (!isObject(strategy)) {
			throw new TypeError("strategy must be an object");
		}

		var highWaterMark = strategy.highWaterMark;
		var size = strategy.size;

		if (highWaterMark !== undefined) {
			highWaterMark = validateAndNormalizeHighWaterMark(highWaterMark);
		} else {
			highWaterMark = 1;
		}

		if (size !== undefined && !isFunction(size)) {
			throw new TypeError("size must be a function");
		}

		return { highWaterMark: highWaterMark, size: size || defaultSize };
	}

	// Queue implementation for streams
	function SimpleQueue() {
		this._queue = [];
		this._queueTotalSize = 0;
	}

	SimpleQueue.prototype.enqueue = function (chunk, size) {
		this._queue.push({ chunk: chunk, size: size });
		this._queueTotalSize += size;
	};

	SimpleQueue.prototype.dequeue = function () {
		if (this._queue.length === 0) {
			return undefined;
		}
		var entry = this._queue.shift();
		this._queueTotalSize -= entry.size;
		return entry.chunk;
	};

	SimpleQueue.prototype.peek = function () {
		if (this._queue.length === 0) {
			return undefined;
		}
		return this._queue[0].chunk;
	};

	SimpleQueue.prototype.length = function () {
		return this._queue.length;
	};

	SimpleQueue.prototype.totalSize = function () {
		return this._queueTotalSize;
	};

	// ReadableStream Implementation
	function ReadableStream(underlyingSource, queuingStrategy) {
		if (support.readableStream && !this._forcePolyfill) {
			return new nativeReadableStream(underlyingSource, queuingStrategy);
		}

		underlyingSource = underlyingSource || {};
		var normalizedStrategy = validateAndNormalizeQueuingStrategy(
			queuingStrategy,
			function () {
				return 1;
			},
		);

		this._state = "readable";
		this._reader = null;
		this._storedError = null;
		this._disturbed = false;
		this._readableStreamController = null;

		var controller = new ReadableStreamDefaultController(
			this,
			underlyingSource,
			normalizedStrategy,
		);
		this._readableStreamController = controller;
	}

	ReadableStream.prototype.cancel = function (reason) {
		if (!isReadableStream(this)) {
			return promiseReject(
				new TypeError("ReadableStream method called on non-ReadableStream"),
			);
		}

		if (isReadableStreamLocked(this)) {
			return promiseReject(new TypeError("Cannot cancel a locked stream"));
		}

		return readableStreamCancel(this, reason);
	};

	ReadableStream.prototype.getReader = function (options) {
		if (!isReadableStream(this)) {
			throw new TypeError("ReadableStream method called on non-ReadableStream");
		}

		options = options || {};
		if (options.mode === "byob") {
			// BYOB reader not implemented in this polyfill
			throw new Error("BYOB readers not supported in this polyfill");
		}

		return new ReadableStreamDefaultReader(this);
	};

	ReadableStream.prototype.pipeThrough = function (transform, options) {
		if (!isReadableStream(this)) {
			throw new TypeError("ReadableStream method called on non-ReadableStream");
		}

		if (!isObject(transform)) {
			throw new TypeError("transform must be an object");
		}

		if (!isReadableStream(transform.readable)) {
			throw new TypeError("transform.readable must be a ReadableStream");
		}

		if (!isWritableStream(transform.writable)) {
			throw new TypeError("transform.writable must be a WritableStream");
		}

		options = options || {};
		var promise = this.pipeTo(transform.writable, options);

		return transform.readable;
	};

	ReadableStream.prototype.pipeTo = function (destination, options) {
		if (!isReadableStream(this)) {
			return promiseReject(
				new TypeError("ReadableStream method called on non-ReadableStream"),
			);
		}

		if (!isWritableStream(destination)) {
			return promiseReject(
				new TypeError("destination must be a WritableStream"),
			);
		}

		options = options || {};
		var preventClose = Boolean(options.preventClose);
		var preventAbort = Boolean(options.preventAbort);
		var preventCancel = Boolean(options.preventCancel);
		var signal = options.signal;

		if (signal && !isObject(signal)) {
			return promiseReject(new TypeError("options.signal must be an object"));
		}

		if (isReadableStreamLocked(this)) {
			return promiseReject(new TypeError("ReadableStream is locked"));
		}

		if (isWritableStreamLocked(destination)) {
			return promiseReject(new TypeError("WritableStream is locked"));
		}

		return readableStreamPipeTo(
			this,
			destination,
			preventClose,
			preventAbort,
			preventCancel,
			signal,
		);
	};

	ReadableStream.prototype.tee = function () {
		if (!isReadableStream(this)) {
			throw new TypeError("ReadableStream method called on non-ReadableStream");
		}

		return readableStreamTee(this);
	};

	// Add async iterator support if available
	if (support.asyncIterator) {
		ReadableStream.prototype[Symbol.asyncIterator] = function () {
			return this.getReader();
		};
	}

	// ReadableStreamDefaultReader Implementation
	function ReadableStreamDefaultReader(stream) {
		if (!isReadableStream(stream)) {
			throw new TypeError(
				"ReadableStreamDefaultReader can only be constructed with a ReadableStream instance",
			);
		}

		if (isReadableStreamLocked(stream)) {
			throw new TypeError(
				"This stream has already been locked for exclusive reading by another reader",
			);
		}

		this._ownerReadableStream = stream;
		stream._reader = this;
		this._readRequests = [];

		if (stream._state === "readable") {
			this._closedPromise = new Promise(
				function (resolve, reject) {
					this._closedPromise_resolve = resolve;
					this._closedPromise_reject = reject;
				}.bind(this),
			);
		} else if (stream._state === "closed") {
			this._closedPromise = promiseResolve(undefined);
		} else {
			this._closedPromise = promiseReject(stream._storedError);
		}
	}

	Object.defineProperty(ReadableStreamDefaultReader.prototype, "closed", {
		get: function () {
			if (!isReadableStreamDefaultReader(this)) {
				return promiseReject(
					new TypeError(
						"ReadableStreamDefaultReader method called on non-ReadableStreamDefaultReader",
					),
				);
			}
			return this._closedPromise;
		},
	});

	ReadableStreamDefaultReader.prototype.cancel = function (reason) {
		if (!isReadableStreamDefaultReader(this)) {
			return promiseReject(
				new TypeError(
					"ReadableStreamDefaultReader method called on non-ReadableStreamDefaultReader",
				),
			);
		}

		var stream = this._ownerReadableStream;
		if (stream === null) {
			return promiseReject(new TypeError("Reader has been released"));
		}

		return readableStreamCancel(stream, reason);
	};

	ReadableStreamDefaultReader.prototype.read = function () {
		if (!isReadableStreamDefaultReader(this)) {
			return promiseReject(
				new TypeError(
					"ReadableStreamDefaultReader method called on non-ReadableStreamDefaultReader",
				),
			);
		}

		var stream = this._ownerReadableStream;
		if (stream === null) {
			return promiseReject(new TypeError("Reader has been released"));
		}

		return readableStreamDefaultReaderRead(this);
	};

	ReadableStreamDefaultReader.prototype.releaseLock = function () {
		if (!isReadableStreamDefaultReader(this)) {
			throw new TypeError(
				"ReadableStreamDefaultReader method called on non-ReadableStreamDefaultReader",
			);
		}

		var stream = this._ownerReadableStream;
		if (stream === null) {
			return;
		}

		if (this._readRequests.length > 0) {
			throw new TypeError(
				"Cannot release a lock on a reader with pending read requests",
			);
		}

		readableStreamReaderGenericRelease(this);
	};

	// Add async iterator methods if supported
	if (support.asyncIterator) {
		ReadableStreamDefaultReader.prototype.next = function () {
			return this.read().then(function (result) {
				if (result.done) {
					return { value: undefined, done: true };
				}
				return { value: result.value, done: false };
			});
		};

		ReadableStreamDefaultReader.prototype.return = function () {
			return this.cancel().then(function () {
				return { value: undefined, done: true };
			});
		};

		ReadableStreamDefaultReader.prototype.throw = function (e) {
			return this.cancel(e).then(function () {
				return { value: undefined, done: true };
			});
		};

		ReadableStreamDefaultReader.prototype[Symbol.asyncIterator] = function () {
			return this;
		};
	}

	// ReadableStreamDefaultController Implementation
	function ReadableStreamDefaultController(stream, underlyingSource, strategy) {
		this._controlledReadableStream = stream;
		this._queue = new SimpleQueue();
		this._queueTotalSize = 0;
		this._started = false;
		this._closeRequested = false;
		this._pullAgain = false;
		this._pulling = false;

		var controller = this;
		this._cancelAlgorithm = function () {
			return promiseResolve(undefined);
		};
		this._pullAlgorithm = function () {
			return promiseResolve(undefined);
		};

		this._strategySizeAlgorithm = strategy.size;
		this._strategyHWM = strategy.highWaterMark;

		var underlyingSourceDict = underlyingSource || {};

		if (isFunction(underlyingSourceDict.start)) {
			var startResult = underlyingSourceDict.start.call(
				underlyingSourceDict,
				this,
			);
			Promise.resolve(startResult).then(
				function () {
					controller._started = true;
					readableStreamDefaultControllerCallPullIfNeeded(controller);
				},
				function (r) {
					readableStreamDefaultControllerError(controller, r);
				},
			);
		} else {
			this._started = true;
			readableStreamDefaultControllerCallPullIfNeeded(this);
		}

		if (isFunction(underlyingSourceDict.pull)) {
			this._pullAlgorithm = function () {
				return Promise.resolve(
					underlyingSourceDict.pull.call(underlyingSourceDict, controller),
				);
			};
		}

		if (isFunction(underlyingSourceDict.cancel)) {
			this._cancelAlgorithm = function (reason) {
				return Promise.resolve(
					underlyingSourceDict.cancel.call(underlyingSourceDict, reason),
				);
			};
		}
	}

	Object.defineProperty(
		ReadableStreamDefaultController.prototype,
		"desiredSize",
		{
			get: function () {
				if (!isReadableStreamDefaultController(this)) {
					throw new TypeError(
						"ReadableStreamDefaultController method called on non-ReadableStreamDefaultController",
					);
				}
				return readableStreamDefaultControllerGetDesiredSize(this);
			},
		},
	);

	ReadableStreamDefaultController.prototype.close = function () {
		if (!isReadableStreamDefaultController(this)) {
			throw new TypeError(
				"ReadableStreamDefaultController method called on non-ReadableStreamDefaultController",
			);
		}

		if (!readableStreamDefaultControllerCanCloseOrEnqueue(this)) {
			throw new TypeError("The stream is not in a state that permits close");
		}

		readableStreamDefaultControllerClose(this);
	};

	ReadableStreamDefaultController.prototype.enqueue = function (chunk) {
		if (!isReadableStreamDefaultController(this)) {
			throw new TypeError(
				"ReadableStreamDefaultController method called on non-ReadableStreamDefaultController",
			);
		}

		if (!readableStreamDefaultControllerCanCloseOrEnqueue(this)) {
			throw new TypeError("The stream is not in a state that permits enqueue");
		}

		return readableStreamDefaultControllerEnqueue(this, chunk);
	};

	ReadableStreamDefaultController.prototype.error = function (e) {
		if (!isReadableStreamDefaultController(this)) {
			throw new TypeError(
				"ReadableStreamDefaultController method called on non-ReadableStreamDefaultController",
			);
		}

		readableStreamDefaultControllerError(this, e);
	};

	// WritableStream Implementation
	function WritableStream(underlyingSink, queuingStrategy) {
		if (support.writableStream && !this._forcePolyfill) {
			return new nativeWritableStream(underlyingSink, queuingStrategy);
		}

		underlyingSink = underlyingSink || {};
		var normalizedStrategy = validateAndNormalizeQueuingStrategy(
			queuingStrategy,
			function () {
				return 1;
			},
		);

		this._state = "writable";
		this._storedError = null;
		this._writer = null;
		this._writableStreamController = null;
		this._writeRequests = [];
		this._inFlightWriteRequest = null;
		this._closeRequest = null;
		this._inFlightCloseRequest = null;
		this._pendingAbortRequest = null;
		this._backpressure = false;

		var controller = new WritableStreamDefaultController(
			this,
			underlyingSink,
			normalizedStrategy,
		);
		this._writableStreamController = controller;
	}

	Object.defineProperty(WritableStream.prototype, "locked", {
		get: function () {
			if (!isWritableStream(this)) {
				throw new TypeError(
					"WritableStream method called on non-WritableStream",
				);
			}
			return isWritableStreamLocked(this);
		},
	});

	WritableStream.prototype.abort = function (reason) {
		if (!isWritableStream(this)) {
			return promiseReject(
				new TypeError("WritableStream method called on non-WritableStream"),
			);
		}

		if (isWritableStreamLocked(this)) {
			return promiseReject(new TypeError("Cannot abort a locked stream"));
		}

		return writableStreamAbort(this, reason);
	};

	WritableStream.prototype.close = function () {
		if (!isWritableStream(this)) {
			return promiseReject(
				new TypeError("WritableStream method called on non-WritableStream"),
			);
		}

		if (isWritableStreamLocked(this)) {
			return promiseReject(new TypeError("Cannot close a locked stream"));
		}

		if (writableStreamCloseQueuedOrInFlight(this)) {
			return promiseReject(
				new TypeError("Cannot close an already-closing stream"),
			);
		}

		return writableStreamClose(this);
	};

	WritableStream.prototype.getWriter = function () {
		if (!isWritableStream(this)) {
			throw new TypeError("WritableStream method called on non-WritableStream");
		}

		return new WritableStreamDefaultWriter(this);
	};

	// WritableStreamDefaultWriter Implementation
	function WritableStreamDefaultWriter(stream) {
		if (!isWritableStream(stream)) {
			throw new TypeError(
				"WritableStreamDefaultWriter can only be constructed with a WritableStream instance",
			);
		}

		if (isWritableStreamLocked(stream)) {
			throw new TypeError(
				"This stream has already been locked for exclusive writing by another writer",
			);
		}

		this._ownerWritableStream = stream;
		stream._writer = this;

		var state = stream._state;

		if (state === "writable") {
			if (
				!writableStreamCloseQueuedOrInFlight(stream) &&
				stream._backpressure
			) {
				this._readyPromise = new Promise(
					function (resolve, reject) {
						this._readyPromise_resolve = resolve;
						this._readyPromise_reject = reject;
					}.bind(this),
				);
			} else {
				this._readyPromise = promiseResolve(undefined);
			}

			this._closedPromise = new Promise(
				function (resolve, reject) {
					this._closedPromise_resolve = resolve;
					this._closedPromise_reject = reject;
				}.bind(this),
			);
		} else if (state === "erroring") {
			this._readyPromise = promiseReject(stream._storedError);
			this._closedPromise = new Promise(
				function (resolve, reject) {
					this._closedPromise_resolve = resolve;
					this._closedPromise_reject = reject;
				}.bind(this),
			);
		} else if (state === "closed") {
			this._readyPromise = promiseResolve(undefined);
			this._closedPromise = promiseResolve(undefined);
		} else {
			this._readyPromise = promiseReject(stream._storedError);
			this._closedPromise = promiseReject(stream._storedError);
		}
	}

	Object.defineProperty(WritableStreamDefaultWriter.prototype, "closed", {
		get: function () {
			if (!isWritableStreamDefaultWriter(this)) {
				return promiseReject(
					new TypeError(
						"WritableStreamDefaultWriter method called on non-WritableStreamDefaultWriter",
					),
				);
			}
			return this._closedPromise;
		},
	});

	Object.defineProperty(WritableStreamDefaultWriter.prototype, "desiredSize", {
		get: function () {
			if (!isWritableStreamDefaultWriter(this)) {
				throw new TypeError(
					"WritableStreamDefaultWriter method called on non-WritableStreamDefaultWriter",
				);
			}

			if (this._ownerWritableStream === null) {
				throw new TypeError("Writer has been released");
			}

			return writableStreamDefaultWriterGetDesiredSize(this);
		},
	});

	Object.defineProperty(WritableStreamDefaultWriter.prototype, "ready", {
		get: function () {
			if (!isWritableStreamDefaultWriter(this)) {
				return promiseReject(
					new TypeError(
						"WritableStreamDefaultWriter method called on non-WritableStreamDefaultWriter",
					),
				);
			}
			return this._readyPromise;
		},
	});

	WritableStreamDefaultWriter.prototype.abort = function (reason) {
		if (!isWritableStreamDefaultWriter(this)) {
			return promiseReject(
				new TypeError(
					"WritableStreamDefaultWriter method called on non-WritableStreamDefaultWriter",
				),
			);
		}

		if (this._ownerWritableStream === null) {
			return promiseReject(new TypeError("Writer has been released"));
		}

		return writableStreamDefaultWriterAbort(this, reason);
	};

	WritableStreamDefaultWriter.prototype.close = function () {
		if (!isWritableStreamDefaultWriter(this)) {
			return promiseReject(
				new TypeError(
					"WritableStreamDefaultWriter method called on non-WritableStreamDefaultWriter",
				),
			);
		}

		var stream = this._ownerWritableStream;
		if (stream === null) {
			return promiseReject(new TypeError("Writer has been released"));
		}

		if (writableStreamCloseQueuedOrInFlight(stream)) {
			return promiseReject(
				new TypeError("Cannot close an already-closing stream"),
			);
		}

		return writableStreamDefaultWriterClose(this);
	};

	WritableStreamDefaultWriter.prototype.releaseLock = function () {
		if (!isWritableStreamDefaultWriter(this)) {
			throw new TypeError(
				"WritableStreamDefaultWriter method called on non-WritableStreamDefaultWriter",
			);
		}

		var stream = this._ownerWritableStream;
		if (stream === null) {
			return;
		}

		writableStreamDefaultWriterRelease(this);
	};

	WritableStreamDefaultWriter.prototype.write = function (chunk) {
		if (!isWritableStreamDefaultWriter(this)) {
			return promiseReject(
				new TypeError(
					"WritableStreamDefaultWriter method called on non-WritableStreamDefaultWriter",
				),
			);
		}

		if (this._ownerWritableStream === null) {
			return promiseReject(new TypeError("Writer has been released"));
		}

		return writableStreamDefaultWriterWrite(this, chunk);
	};

	// WritableStreamDefaultController Implementation
	function WritableStreamDefaultController(stream, underlyingSink, strategy) {
		this._controlledWritableStream = stream;
		this._queue = new SimpleQueue();
		this._queueTotalSize = 0;
		this._started = false;

		this._strategySizeAlgorithm = strategy.size;
		this._strategyHWM = strategy.highWaterMark;

		var controller = this;
		this._abortAlgorithm = function () {
			return promiseResolve(undefined);
		};
		this._closeAlgorithm = function () {
			return promiseResolve(undefined);
		};
		this._writeAlgorithm = function () {
			return promiseResolve(undefined);
		};

		var underlyingSinkDict = underlyingSink || {};

		if (isFunction(underlyingSinkDict.start)) {
			var startResult = underlyingSinkDict.start.call(underlyingSinkDict, this);
			Promise.resolve(startResult).then(
				function () {
					controller._started = true;
					writableStreamDefaultControllerAdvanceQueueIfNeeded(controller);
				},
				function (r) {
					controller._started = true;
					writableStreamDefaultControllerErrorIfNeeded(controller, r);
				},
			);
		} else {
			this._started = true;
		}

		if (isFunction(underlyingSinkDict.write)) {
			this._writeAlgorithm = function (chunk) {
				return Promise.resolve(
					underlyingSinkDict.write.call(underlyingSinkDict, chunk, controller),
				);
			};
		}

		if (isFunction(underlyingSinkDict.close)) {
			this._closeAlgorithm = function () {
				return Promise.resolve(
					underlyingSinkDict.close.call(underlyingSinkDict),
				);
			};
		}

		if (isFunction(underlyingSinkDict.abort)) {
			this._abortAlgorithm = function (reason) {
				return Promise.resolve(
					underlyingSinkDict.abort.call(underlyingSinkDict, reason),
				);
			};
		}

		var backpressure = writableStreamDefaultControllerGetBackpressure(this);
		writableStreamUpdateBackpressure(stream, backpressure);
	}

	WritableStreamDefaultController.prototype.error = function (e) {
		if (!isWritableStreamDefaultController(this)) {
			throw new TypeError(
				"WritableStreamDefaultController method called on non-WritableStreamDefaultController",
			);
		}

		var state = this._controlledWritableStream._state;
		if (state !== "writable") {
			return;
		}

		writableStreamDefaultControllerError(this, e);
	};

	// TransformStream Implementation
	function TransformStream(transformer, writableStrategy, readableStrategy) {
		if (support.transformStream && !this._forcePolyfill) {
			return new nativeTransformStream(
				transformer,
				writableStrategy,
				readableStrategy,
			);
		}

		transformer = transformer || {};

		var readableHighWaterMark = 0;
		var readableSizeAlgorithm = function () {
			return 1;
		};
		var writableHighWaterMark = 0;
		var writableSizeAlgorithm = function () {
			return 1;
		};

		if (readableStrategy !== undefined) {
			readableHighWaterMark = readableStrategy.highWaterMark || 0;
			if (readableStrategy.size !== undefined) {
				readableSizeAlgorithm = readableStrategy.size;
			}
		}

		if (writableStrategy !== undefined) {
			writableHighWaterMark = writableStrategy.highWaterMark || 0;
			if (writableStrategy.size !== undefined) {
				writableSizeAlgorithm = writableStrategy.size;
			}
		}

		var transformStreamController;

		var transformAlgorithm = function (chunk) {
			try {
				if (isFunction(transformer.transform)) {
					return Promise.resolve(
						transformer.transform.call(
							transformer,
							chunk,
							transformStreamController,
						),
					);
				}
				transformStreamController.enqueue(chunk);
				return promiseResolve(undefined);
			} catch (e) {
				return promiseReject(e);
			}
		};

		var flushAlgorithm = function () {
			try {
				if (isFunction(transformer.flush)) {
					return Promise.resolve(
						transformer.flush.call(transformer, transformStreamController),
					);
				}
				return promiseResolve(undefined);
			} catch (e) {
				return promiseReject(e);
			}
		};

		this._readable = new ReadableStream(
			{
				start: function (controller) {
					transformStreamController = new TransformStreamDefaultController(
						controller,
					);
					if (isFunction(transformer.start)) {
						return transformer.start.call(
							transformer,
							transformStreamController,
						);
					}
				},
				pull: function (controller) {
					// Pull is handled by the transform side
					return promiseResolve(undefined);
				},
				cancel: function (reason) {
					var readable =
						transformStreamController._controlledTransformStream._readable;
					var writable =
						transformStreamController._controlledTransformStream._writable;

					transformStreamController._finishPromise_reject(reason);

					if (writable._state === "writable") {
						return writable.abort(reason);
					}

					return promiseResolve(undefined);
				},
			},
			{ highWaterMark: readableHighWaterMark, size: readableSizeAlgorithm },
		);

		this._writable = new WritableStream(
			{
				start: function () {
					return promiseResolve(undefined);
				},
				write: function (chunk) {
					return transformAlgorithm(chunk);
				},
				close: function () {
					return flushAlgorithm().then(function () {
						transformStreamController._readableController.close();
					});
				},
				abort: function (reason) {
					transformStreamController._finishPromise_reject(reason);
					transformStreamController._readableController.error(reason);
					return promiseResolve(undefined);
				},
			},
			{ highWaterMark: writableHighWaterMark, size: writableSizeAlgorithm },
		);

		transformStreamController._controlledTransformStream = this;
		transformStreamController._finishPromise = new Promise(function (
			resolve,
			reject,
		) {
			transformStreamController._finishPromise_resolve = resolve;
			transformStreamController._finishPromise_reject = reject;
		});
	}

	Object.defineProperty(TransformStream.prototype, "readable", {
		get: function () {
			if (!isTransformStream(this)) {
				throw new TypeError(
					"TransformStream method called on non-TransformStream",
				);
			}
			return this._readable;
		},
	});

	Object.defineProperty(TransformStream.prototype, "writable", {
		get: function () {
			if (!isTransformStream(this)) {
				throw new TypeError(
					"TransformStream method called on non-TransformStream",
				);
			}
			return this._writable;
		},
	});

	// TransformStreamDefaultController Implementation
	function TransformStreamDefaultController(readableController) {
		this._readableController = readableController;
		this._controlledTransformStream = null;
		this._finishPromise = null;
		this._finishPromise_resolve = null;
		this._finishPromise_reject = null;
	}

	Object.defineProperty(
		TransformStreamDefaultController.prototype,
		"desiredSize",
		{
			get: function () {
				if (!isTransformStreamDefaultController(this)) {
					throw new TypeError(
						"TransformStreamDefaultController method called on non-TransformStreamDefaultController",
					);
				}
				return this._readableController.desiredSize;
			},
		},
	);

	TransformStreamDefaultController.prototype.enqueue = function (chunk) {
		if (!isTransformStreamDefaultController(this)) {
			throw new TypeError(
				"TransformStreamDefaultController method called on non-TransformStreamDefaultController",
			);
		}
		this._readableController.enqueue(chunk);
	};

	TransformStreamDefaultController.prototype.error = function (reason) {
		if (!isTransformStreamDefaultController(this)) {
			throw new TypeError(
				"TransformStreamDefaultController method called on non-TransformStreamDefaultController",
			);
		}
		this._readableController.error(reason);
	};

	TransformStreamDefaultController.prototype.terminate = function () {
		if (!isTransformStreamDefaultController(this)) {
			throw new TypeError(
				"TransformStreamDefaultController method called on non-TransformStreamDefaultController",
			);
		}
		this._readableController.close();
	};

	// Helper functions for ReadableStream
	function isReadableStream(x) {
		return isObject(x) && isFunction(x.getReader);
	}

	function isReadableStreamLocked(stream) {
		return stream._reader !== null;
	}

	function isReadableStreamDefaultReader(x) {
		return (
			isObject(x) && isFunction(x.read) && x._ownerReadableStream !== undefined
		);
	}

	function isReadableStreamDefaultController(x) {
		return (
			isObject(x) &&
			isFunction(x.close) &&
			x._controlledReadableStream !== undefined
		);
	}

	function readableStreamCancel(stream, reason) {
		stream._disturbed = true;

		if (stream._state === "closed") {
			return promiseResolve(undefined);
		}

		if (stream._state === "errored") {
			return promiseReject(stream._storedError);
		}

		readableStreamClose(stream);

		var controller = stream._readableStreamController;
		return controller._cancelAlgorithm(reason);
	}

	function readableStreamClose(stream) {
		stream._state = "closed";

		var reader = stream._reader;
		if (reader === null) {
			return;
		}

		if (isReadableStreamDefaultReader(reader)) {
			reader._readRequests.forEach(function (request) {
				request.resolve({ value: undefined, done: true });
			});
			reader._readRequests = [];
		}

		if (reader._closedPromise_resolve) {
			reader._closedPromise_resolve(undefined);
		}
	}

	function readableStreamError(stream, e) {
		stream._state = "errored";
		stream._storedError = e;

		var reader = stream._reader;
		if (reader === null) {
			return;
		}

		if (isReadableStreamDefaultReader(reader)) {
			reader._readRequests.forEach(function (request) {
				request.reject(e);
			});
			reader._readRequests = [];
		}

		if (reader._closedPromise_reject) {
			reader._closedPromise_reject(e);
		}
	}

	function readableStreamDefaultReaderRead(reader) {
		var stream = reader._ownerReadableStream;

		if (stream._state === "closed") {
			return promiseResolve({ value: undefined, done: true });
		}

		if (stream._state === "errored") {
			return promiseReject(stream._storedError);
		}

		return stream._readableStreamController._pullSteps();
	}

	function readableStreamReaderGenericRelease(reader) {
		reader._ownerReadableStream._reader = null;
		reader._ownerReadableStream = null;
	}

	function readableStreamDefaultControllerCallPullIfNeeded(controller) {
		var shouldPull = readableStreamDefaultControllerShouldCallPull(controller);
		if (!shouldPull) {
			return;
		}

		if (controller._pulling) {
			controller._pullAgain = true;
			return;
		}

		controller._pulling = true;

		var pullPromise = controller._pullAlgorithm();
		pullPromise.then(
			function () {
				controller._pulling = false;

				if (controller._pullAgain) {
					controller._pullAgain = false;
					readableStreamDefaultControllerCallPullIfNeeded(controller);
				}
			},
			function (e) {
				readableStreamDefaultControllerError(controller, e);
			},
		);
	}

	function readableStreamDefaultControllerShouldCallPull(controller) {
		var stream = controller._controlledReadableStream;

		if (!readableStreamDefaultControllerCanCloseOrEnqueue(controller)) {
			return false;
		}

		if (!controller._started) {
			return false;
		}

		if (
			isReadableStreamLocked(stream) &&
			stream._reader._readRequests.length > 0
		) {
			return true;
		}

		var desiredSize = readableStreamDefaultControllerGetDesiredSize(controller);
		return desiredSize > 0;
	}

	function readableStreamDefaultControllerCanCloseOrEnqueue(controller) {
		var state = controller._controlledReadableStream._state;
		if (!controller._closeRequested && state === "readable") {
			return true;
		}
		return false;
	}

	function readableStreamDefaultControllerGetDesiredSize(controller) {
		var state = controller._controlledReadableStream._state;

		if (state === "errored") {
			return null;
		}
		if (state === "closed") {
			return 0;
		}

		return controller._strategyHWM - controller._queueTotalSize;
	}

	function readableStreamDefaultControllerClose(controller) {
		controller._closeRequested = true;

		if (controller._queue.length() === 0) {
			readableStreamDefaultControllerClearAlgorithms(controller);
			readableStreamClose(controller._controlledReadableStream);
		}
	}

	function readableStreamDefaultControllerEnqueue(controller, chunk) {
		if (!readableStreamDefaultControllerCanCloseOrEnqueue(controller)) {
			return;
		}

		var stream = controller._controlledReadableStream;

		if (
			isReadableStreamLocked(stream) &&
			stream._reader._readRequests.length > 0
		) {
			stream._reader._readRequests
				.shift()
				.resolve({ value: chunk, done: false });
		} else {
			var chunkSize;
			try {
				chunkSize = controller._strategySizeAlgorithm(chunk);
			} catch (chunkSizeE) {
				readableStreamDefaultControllerError(controller, chunkSizeE);
				throw chunkSizeE;
			}

			try {
				controller._queue.enqueue(chunk, chunkSize);
			} catch (enqueueE) {
				readableStreamDefaultControllerError(controller, enqueueE);
				throw enqueueE;
			}
		}

		readableStreamDefaultControllerCallPullIfNeeded(controller);
	}

	function readableStreamDefaultControllerError(controller, e) {
		var stream = controller._controlledReadableStream;

		if (stream._state !== "readable") {
			return;
		}

		controller._queue = new SimpleQueue();
		readableStreamDefaultControllerClearAlgorithms(controller);
		readableStreamError(stream, e);
	}

	function readableStreamDefaultControllerClearAlgorithms(controller) {
		controller._pullAlgorithm = function () {
			return promiseResolve(undefined);
		};
		controller._cancelAlgorithm = function () {
			return promiseResolve(undefined);
		};
		controller._strategySizeAlgorithm = function () {
			return 1;
		};
	}

	// Add pullSteps method to controller
	ReadableStreamDefaultController.prototype._pullSteps = function () {
		var controller = this;
		if (controller._queue.length() > 0) {
			var chunk = controller._queue.dequeue();

			if (controller._closeRequested && controller._queue.length() === 0) {
				readableStreamDefaultControllerClearAlgorithms(controller);
				readableStreamClose(controller._controlledReadableStream);
			} else {
				readableStreamDefaultControllerCallPullIfNeeded(controller);
			}

			return promiseResolve({ value: chunk, done: false });
		}

		var promise = new Promise(function (resolve, reject) {
			controller._controlledReadableStream._reader._readRequests.push({
				resolve: resolve,
				reject: reject,
			});
		});

		readableStreamDefaultControllerCallPullIfNeeded(controller);
		return promise;
	};

	// Helper functions for WritableStream
	function isWritableStream(x) {
		return isObject(x) && isFunction(x.getWriter);
	}

	function isWritableStreamLocked(stream) {
		return stream._writer !== null;
	}

	function isWritableStreamDefaultWriter(x) {
		return (
			isObject(x) && isFunction(x.write) && x._ownerWritableStream !== undefined
		);
	}

	function isWritableStreamDefaultController(x) {
		return (
			isObject(x) &&
			isFunction(x.error) &&
			x._controlledWritableStream !== undefined
		);
	}

	function writableStreamAbort(stream, reason) {
		var state = stream._state;
		if (state === "closed" || state === "errored") {
			return promiseResolve(undefined);
		}

		if (stream._pendingAbortRequest !== null) {
			return stream._pendingAbortRequest.promise;
		}

		var wasAlreadyErroring = false;
		if (state === "erroring") {
			wasAlreadyErroring = true;
			reason = stream._storedError;
		}

		var promise = new Promise(function (resolve, reject) {
			stream._pendingAbortRequest = {
				promise: promise,
				resolve: resolve,
				reject: reject,
				reason: reason,
				wasAlreadyErroring: wasAlreadyErroring,
			};
		});

		if (!wasAlreadyErroring) {
			writableStreamStartErroring(stream, reason);
		}

		return promise;
	}

	function writableStreamClose(stream) {
		var state = stream._state;
		if (state === "closed" || state === "errored") {
			return promiseReject(
				new TypeError(
					"The stream is not in the writable state and cannot be closed",
				),
			);
		}

		var promise = new Promise(function (resolve, reject) {
			stream._closeRequest = {
				promise: promise,
				resolve: resolve,
				reject: reject,
			};
		});

		var writer = stream._writer;
		if (writer !== null && stream._backpressure && state === "writable") {
			writer._readyPromise_resolve(undefined);
		}

		writableStreamDefaultControllerClose(stream._writableStreamController);

		return promise;
	}

	function writableStreamCloseQueuedOrInFlight(stream) {
		return (
			stream._closeRequest !== null || stream._inFlightCloseRequest !== null
		);
	}

	function writableStreamStartErroring(stream, reason) {
		stream._state = "erroring";
		stream._storedError = reason;

		var writer = stream._writer;
		if (writer !== null) {
			writableStreamDefaultWriterEnsureReadyPromiseRejected(writer, reason);
		}

		if (
			!writableStreamHasOperationMarkedInFlight(stream) &&
			stream._writableStreamController._started
		) {
			writableStreamFinishErroring(stream);
		}
	}

	function writableStreamFinishErroring(stream) {
		stream._state = "errored";

		stream._writableStreamController._errorSteps();

		var storedError = stream._storedError;

		stream._writeRequests.forEach(function (writeRequest) {
			writeRequest.reject(storedError);
		});
		stream._writeRequests = [];

		if (stream._pendingAbortRequest === null) {
			writableStreamRejectCloseAndClosedPromiseIfNeeded(stream);
			return;
		}

		var abortRequest = stream._pendingAbortRequest;
		stream._pendingAbortRequest = null;

		if (abortRequest.wasAlreadyErroring) {
			abortRequest.reject(storedError);
			writableStreamRejectCloseAndClosedPromiseIfNeeded(stream);
			return;
		}

		var promise = stream._writableStreamController._abortSteps(
			abortRequest.reason,
		);
		promise.then(
			function () {
				abortRequest.resolve();
				writableStreamRejectCloseAndClosedPromiseIfNeeded(stream);
			},
			function (reason) {
				abortRequest.reject(reason);
				writableStreamRejectCloseAndClosedPromiseIfNeeded(stream);
			},
		);
	}

	function writableStreamHasOperationMarkedInFlight(stream) {
		return (
			stream._inFlightWriteRequest !== null ||
			stream._inFlightCloseRequest !== null
		);
	}

	function writableStreamRejectCloseAndClosedPromiseIfNeeded(stream) {
		if (stream._closeRequest !== null) {
			stream._closeRequest.reject(stream._storedError);
			stream._closeRequest = null;
		}

		var writer = stream._writer;
		if (writer !== null) {
			writer._closedPromise_reject(stream._storedError);
		}
	}

	function writableStreamUpdateBackpressure(stream, backpressure) {
		stream._backpressure = backpressure;

		var writer = stream._writer;
		if (writer !== null && backpressure !== stream._backpressure) {
			if (backpressure) {
				writer._readyPromise = new Promise(function (resolve, reject) {
					writer._readyPromise_resolve = resolve;
					writer._readyPromise_reject = reject;
				});
			} else {
				writer._readyPromise_resolve(undefined);
			}
		}
	}

	function writableStreamDefaultWriterAbort(writer, reason) {
		var stream = writer._ownerWritableStream;
		return writableStreamAbort(stream, reason);
	}

	function writableStreamDefaultWriterClose(writer) {
		var stream = writer._ownerWritableStream;
		return writableStreamClose(stream);
	}

	function writableStreamDefaultWriterEnsureReadyPromiseRejected(
		writer,
		error,
	) {
		if (writer._readyPromise_reject) {
			writer._readyPromise_reject(error);
		} else {
			writer._readyPromise = promiseReject(error);
		}
	}

	function writableStreamDefaultWriterGetDesiredSize(writer) {
		var stream = writer._ownerWritableStream;
		var state = stream._state;

		if (state === "errored" || state === "erroring") {
			return null;
		}

		if (state === "closed") {
			return 0;
		}

		return writableStreamDefaultControllerGetDesiredSize(
			stream._writableStreamController,
		);
	}

	function writableStreamDefaultWriterRelease(writer) {
		var stream = writer._ownerWritableStream;
		stream._writer = null;
		writer._ownerWritableStream = null;
	}

	function writableStreamDefaultWriterWrite(writer, chunk) {
		var stream = writer._ownerWritableStream;

		var controller = stream._writableStreamController;

		var chunkSize;
		try {
			chunkSize = controller._strategySizeAlgorithm(chunk);
		} catch (chunkSizeE) {
			writableStreamDefaultWriterRelease(writer);
			return promiseReject(chunkSizeE);
		}

		if (stream !== writer._ownerWritableStream) {
			return promiseReject(new TypeError("Writer has been released"));
		}

		var state = stream._state;
		if (state === "errored") {
			return promiseReject(stream._storedError);
		}
		if (writableStreamCloseQueuedOrInFlight(stream) || state === "closed") {
			return promiseReject(
				new TypeError(
					"The stream is closing or closed and cannot be written to",
				),
			);
		}
		if (state === "erroring") {
			return promiseReject(stream._storedError);
		}

		var promise = writableStreamAddWriteRequest(stream);

		writableStreamDefaultControllerWrite(controller, chunk, chunkSize);

		return promise;
	}

	function writableStreamAddWriteRequest(stream) {
		var promise = new Promise(function (resolve, reject) {
			stream._writeRequests.push({
				resolve: resolve,
				reject: reject,
			});
		});

		return promise;
	}

	function writableStreamDefaultControllerWrite(controller, chunk, chunkSize) {
		try {
			controller._queue.enqueue({ chunk: chunk }, chunkSize);
		} catch (enqueueE) {
			writableStreamDefaultControllerErrorIfNeeded(controller, enqueueE);
			return;
		}

		var stream = controller._controlledWritableStream;
		if (
			!writableStreamCloseQueuedOrInFlight(stream) &&
			stream._state === "writable"
		) {
			var backpressure =
				writableStreamDefaultControllerGetBackpressure(controller);
			writableStreamUpdateBackpressure(stream, backpressure);
		}

		writableStreamDefaultControllerAdvanceQueueIfNeeded(controller);
	}

	function writableStreamDefaultControllerAdvanceQueueIfNeeded(controller) {
		var stream = controller._controlledWritableStream;

		if (!controller._started) {
			return;
		}

		if (stream._inFlightWriteRequest !== null) {
			return;
		}

		var state = stream._state;
		if (state === "erroring") {
			writableStreamFinishErroring(stream);
			return;
		}

		if (controller._queue.length() === 0) {
			return;
		}

		var value = controller._queue.peek();
		if (value === "close") {
			writableStreamDefaultControllerProcessClose(controller);
		} else {
			writableStreamDefaultControllerProcessWrite(controller, value.chunk);
		}
	}

	function writableStreamDefaultControllerProcessClose(controller) {
		var stream = controller._controlledWritableStream;

		writableStreamMarkCloseRequestInFlight(stream);
		controller._queue.dequeue();

		var sinkClosePromise = controller._closeAlgorithm();
		writableStreamDefaultControllerClearAlgorithms(controller);

		sinkClosePromise.then(
			function () {
				writableStreamFinishInFlightClose(stream);
			},
			function (reason) {
				writableStreamFinishInFlightCloseWithError(stream, reason);
			},
		);
	}

	function writableStreamDefaultControllerProcessWrite(controller, chunk) {
		var stream = controller._controlledWritableStream;

		writableStreamMarkFirstWriteRequestInFlight(stream);

		var sinkWritePromise = controller._writeAlgorithm(chunk);
		sinkWritePromise.then(
			function () {
				writableStreamFinishInFlightWrite(stream);

				var state = stream._state;
				controller._queue.dequeue();

				if (
					!writableStreamCloseQueuedOrInFlight(stream) &&
					state === "writable"
				) {
					var backpressure =
						writableStreamDefaultControllerGetBackpressure(controller);
					writableStreamUpdateBackpressure(stream, backpressure);
				}

				writableStreamDefaultControllerAdvanceQueueIfNeeded(controller);
			},
			function (reason) {
				if (stream._state === "writable") {
					writableStreamDefaultControllerClearAlgorithms(controller);
				}
				writableStreamFinishInFlightWriteWithError(stream, reason);
			},
		);
	}

	function writableStreamDefaultControllerGetBackpressure(controller) {
		var desiredSize = writableStreamDefaultControllerGetDesiredSize(controller);
		return desiredSize <= 0;
	}

	function writableStreamDefaultControllerGetDesiredSize(controller) {
		return controller._strategyHWM - controller._queueTotalSize;
	}

	function writableStreamDefaultControllerClose(controller) {
		controller._queue.enqueue("close", 0);
		writableStreamDefaultControllerAdvanceQueueIfNeeded(controller);
	}

	function writableStreamDefaultControllerError(controller, error) {
		var stream = controller._controlledWritableStream;

		var state = stream._state;
		if (state !== "writable") {
			return;
		}

		writableStreamDefaultControllerClearAlgorithms(controller);
		writableStreamStartErroring(stream, error);
	}

	function writableStreamDefaultControllerErrorIfNeeded(controller, error) {
		if (controller._controlledWritableStream._state === "writable") {
			writableStreamDefaultControllerError(controller, error);
		}
	}

	function writableStreamDefaultControllerClearAlgorithms(controller) {
		controller._writeAlgorithm = function () {
			return promiseResolve(undefined);
		};
		controller._closeAlgorithm = function () {
			return promiseResolve(undefined);
		};
		controller._abortAlgorithm = function () {
			return promiseResolve(undefined);
		};
		controller._strategySizeAlgorithm = function () {
			return 1;
		};
	}

	function writableStreamMarkCloseRequestInFlight(stream) {
		stream._inFlightCloseRequest = stream._closeRequest;
		stream._closeRequest = null;
	}

	function writableStreamMarkFirstWriteRequestInFlight(stream) {
		stream._inFlightWriteRequest = stream._writeRequests.shift();
	}

	function writableStreamFinishInFlightWrite(stream) {
		stream._inFlightWriteRequest.resolve(undefined);
		stream._inFlightWriteRequest = null;
	}

	function writableStreamFinishInFlightWriteWithError(stream, error) {
		stream._inFlightWriteRequest.reject(error);
		stream._inFlightWriteRequest = null;

		writableStreamStartErroring(stream, error);
	}

	function writableStreamFinishInFlightClose(stream) {
		stream._inFlightCloseRequest.resolve(undefined);
		stream._inFlightCloseRequest = null;

		var state = stream._state;
		if (state === "erroring") {
			stream._storedError = null;
			if (stream._pendingAbortRequest !== null) {
				stream._pendingAbortRequest.resolve();
				stream._pendingAbortRequest = null;
			}
		}

		stream._state = "closed";

		var writer = stream._writer;
		if (writer !== null) {
			writer._closedPromise_resolve(undefined);
		}
	}

	function writableStreamFinishInFlightCloseWithError(stream, error) {
		stream._inFlightCloseRequest.reject(error);
		stream._inFlightCloseRequest = null;

		if (stream._pendingAbortRequest !== null) {
			stream._pendingAbortRequest.reject(error);
			stream._pendingAbortRequest = null;
		}

		writableStreamStartErroring(stream, error);
	}

	// Add errorSteps and abortSteps methods to WritableStreamDefaultController
	WritableStreamDefaultController.prototype._errorSteps = function () {
		this._queue = new SimpleQueue();
	};

	WritableStreamDefaultController.prototype._abortSteps = function (reason) {
		return this._abortAlgorithm(reason);
	};

	// Helper functions for TransformStream
	function isTransformStream(x) {
		return (
			isObject(x) && x._readable !== undefined && x._writable !== undefined
		);
	}

	function isTransformStreamDefaultController(x) {
		return (
			isObject(x) &&
			isFunction(x.enqueue) &&
			x._readableController !== undefined
		);
	}

	// Pipe implementation
	function readableStreamPipeTo(
		source,
		dest,
		preventClose,
		preventAbort,
		preventCancel,
		signal,
	) {
		var reader = source.getReader();
		var writer = dest.getWriter();

		var shutdownWithAction = function (action, reason) {
			return Promise.resolve(
				action ? action.call(dest, reason) : undefined,
			).then(
				function () {
					return finalize(true, reason);
				},
				function (newReason) {
					return finalize(true, newReason);
				},
			);
		};

		var shutdown = function (reason) {
			return finalize(false, reason);
		};

		var finalize = function (isError, reason) {
			writer.releaseLock();
			reader.releaseLock();

			if (signal && signal.removeEventListener) {
				signal.removeEventListener("abort", abortAlgorithm);
			}

			if (isError) {
				return promiseReject(reason);
			}
			return promiseResolve(undefined);
		};

		var abortAlgorithm;
		if (signal) {
			abortAlgorithm = function () {
				var error = new Error("Aborted");
				var actions = [];
				if (!preventAbort) {
					actions.push(function () {
						return dest.abort(error);
					});
				}
				if (!preventCancel) {
					actions.push(function () {
						return source.cancel(error);
					});
				}
				return Promise.all(
					actions.map(function (action) {
						return action();
					}),
				).then(function () {
					return finalize(true, error);
				});
			};

			if (signal.aborted) {
				return abortAlgorithm();
			}

			if (signal.addEventListener) {
				signal.addEventListener("abort", abortAlgorithm);
			}
		}

		var pipeLoop = function () {
			return reader.read().then(
				function (result) {
					if (result.done) {
						if (!preventClose) {
							return shutdownWithAction(dest.close.bind(dest));
						}
						return shutdown();
					}

					return writer.write(result.value).then(pipeLoop, function (reason) {
						if (!preventAbort) {
							return shutdownWithAction(dest.abort.bind(dest), reason);
						}
						return shutdown(reason);
					});
				},
				function (reason) {
					if (!preventCancel) {
						return shutdownWithAction(source.cancel.bind(source), reason);
					}
					return shutdown(reason);
				},
			);
		};

		return pipeLoop();
	}

	// Tee implementation
	function readableStreamTee(stream) {
		var reader = stream.getReader();
		var reading = false;
		var canceled1 = false;
		var canceled2 = false;
		var reason1, reason2;
		var branch1, branch2;

		var cancelPromise = new Promise(function (resolve) {
			var cancel1 = function (reason) {
				canceled1 = true;
				reason1 = reason;
				if (canceled2) {
					var cancelResult = reader.cancel(createCancelReason());
					resolve(cancelResult);
				}
				return cancelResult;
			};

			var cancel2 = function (reason) {
				canceled2 = true;
				reason2 = reason;
				if (canceled1) {
					var cancelResult = reader.cancel(createCancelReason());
					resolve(cancelResult);
				}
				return cancelResult;
			};

			var createCancelReason = function () {
				if (canceled1 && canceled2) {
					if (reason1 === reason2) {
						return reason1;
					}
					return new Error(
						"Both branches were canceled with different reasons",
					);
				}
				return canceled1 ? reason1 : reason2;
			};

			branch1 = new ReadableStream({
				start: function (controller) {
					branch1._controller = controller;
				},
				pull: function (controller) {
					return pullWithDefaultReader();
				},
				cancel: cancel1,
			});

			branch2 = new ReadableStream({
				start: function (controller) {
					branch2._controller = controller;
				},
				pull: function (controller) {
					return pullWithDefaultReader();
				},
				cancel: cancel2,
			});
		});

		function pullWithDefaultReader() {
			if (reading) {
				return promiseResolve(undefined);
			}
			reading = true;

			return reader.read().then(
				function (result) {
					reading = false;
					if (result.done) {
						if (!canceled1) {
							branch1._controller.close();
						}
						if (!canceled2) {
							branch2._controller.close();
						}
						return;
					}

					var value = result.value;
					if (!canceled1) {
						branch1._controller.enqueue(value);
					}
					if (!canceled2) {
						branch2._controller.enqueue(value);
					}
				},
				function (reason) {
					reading = false;
					if (!canceled1) {
						branch1._controller.error(reason);
					}
					if (!canceled2) {
						branch2._controller.error(reason);
					}
				},
			);
		}

		return [branch1, branch2];
	}

	// Export polyfills only if native versions don't exist
	if (!support.readableStream) {
		self.ReadableStream = ReadableStream;
	}

	if (!support.writableStream) {
		self.WritableStream = WritableStream;
	}

	if (!support.transformStream) {
		self.TransformStream = TransformStream;
	}

	// Export for use in other modules
	if (typeof module !== "undefined" && module.exports) {
		module.exports = {
			ReadableStream: ReadableStream,
			WritableStream: WritableStream,
			TransformStream: TransformStream,
		};
	}

	// Utility function to check if polyfill is active
	self.webStreamsPolyfill = {
		isPolyfilled: {
			ReadableStream: !support.readableStream,
			WritableStream: !support.writableStream,
			TransformStream: !support.transformStream,
		},
		version: "1.0.0",
		support: support,
	};
})(typeof self !== "undefined" ? self : this);
