function ParSaveAppend(fname, x, xName) %#ok<INUSL>

eval([xName ' = x;']);
save(fname, xName, '-append')
