create table SourceFile (
id integer primary key autoincrement,
filename varchar(1024) not null,
filepath varchar(1024) not null,
filesize int not null,
filedate datetime not null,
);

create table Node (
id integer primary key autoincrement,
sourcefile_id integer null,
type_id integer not null,
name varchar(64) null,
parent_id integer null,
foreign key PK_Node_SourceFile (sourcefile_id) references SourceFile (id)
)