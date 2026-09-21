unit SQLite3Binding;

{$mode objfpc}{$H+}
{$packrecords C}
interface
uses ctypes;
type
  sqlite3_int64 = cint64;
  sqlite3_uint64 = cuint64;
  sqlite3 = record end;
  Psqlite3 = ^sqlite3;
  PPsqlite3 = ^Psqlite3;
  sqlite3_stmt = record end;
  Psqlite3_stmt = ^sqlite3_stmt;
  sqlite3_value = record end;
  Psqlite3_value = ^sqlite3_value;
  sqlite3_context = record end;
  Psqlite3_context = ^sqlite3_context;
  sqlite3_vtab = record pModule:Pointer; nRef:cint; zErrMsg:PAnsiChar; end;
  Psqlite3_vtab = ^sqlite3_vtab;
  sqlite3_vtab_cursor = record pVtab:Psqlite3_vtab; end;
  Psqlite3_vtab_cursor = ^sqlite3_vtab_cursor;
  Psqlite3_index_info = ^sqlite3_index_info;
  sqlite3_index_info = record nConstraint:cint; aConstraint:Pointer; end;
  Psqlite3_index_constraint = ^sqlite3_index_constraint;
  sqlite3_index_constraint = record iColumn:cint; op:Byte; usable:Byte; iTermOffset:cint; end;
  sqlite3_module = record
    iVersion:cint;
    xCreate:function(DB:Psqlite3; Aux:Pointer; argc:cint; argv:PPAnsiChar; VTab:^Psqlite3_vtab; Err:PPAnsiChar):cint;cdecl;
    xConnect:function(DB:Psqlite3; Aux:Pointer; argc:cint; argv:PPAnsiChar; VTab:^Psqlite3_vtab; Err:PPAnsiChar):cint;cdecl;
  end;
  Psqlite3_module = ^sqlite3_module;

implementation
end.
