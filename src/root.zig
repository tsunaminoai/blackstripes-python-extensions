const std = @import("std");
const testing = std.testing;

pub fn PyModule_Create2() callconv(.C) void {}

pub fn PyArg_ParseTuple() callconv(.C) void {}
pub fn Py_BuildValue() callconv(.C) void {}
