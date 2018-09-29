Red/System []

#import [
    LIBC-file cdecl [
        fgets: "fgets" [
            str         [byte-ptr!]
            count       [integer!]
            stream      [byte-ptr!]
            return:     [byte-ptr!]
        ]
        strcmp: "strcmp" [
            str1 [c-string!]
            str2 [c-string!]
            return: [integer!]
        ]
        strncmp: "strncmp" [
            str1 [c-string!]
            str2 [c-string!]
            n [integer!]
            return: [integer!]
        ]
        sscanf: "sscanf" [
            [variadic]
            return: [integer!]
        ]
    ]
]
#either OS = 'Windows [
    #import [
        LIBC-file cdecl [
            fdopen: "_fdopen" [
                fd      [integer!]
                mode    [byte-ptr!]
                return: [byte-ptr!]
            ]
        ]
    ]
][
    #import [
        LIBC-file cdecl [
            fdopen: "fdopen" [
                fd      [integer!]
                mode    [byte-ptr!]
                return: [byte-ptr!]
            ]
        ]
    ]
]

std-in: fdopen 0 as byte-ptr! "r"

#define MAX_COMMAND_SIZE 1024

#enum Status! [
    EXIT_SUCCESS: 0
    EXIT_FAILURE
]

InputBuffer!: alias struct! [
    buf [c-string!]
    buflen [integer!]
    inlen [integer!]
]

new-input-buffer: func [
    return: [InputBuffer! value]
    /local buf
][
    buf: declare InputBuffer!
    buf: as InputBuffer! allocate size? InputBuffer!
    buf/buf: declare c-string!
    buf/buflen: 0
    buf/inlen: 0
    buf
]

read-input: func [
    buf [InputBuffer!]
    /local 
        bytes [byte-ptr!]
        i
][
    bytes: fgets 
        as byte-ptr! buf/buf 
        MAX_COMMAND_SIZE
        std-in

    if bytes = NULL [
        print "^/Error reading input^/"
        quit EXIT_FAILURE
    ]

    i: length? buf/buf
    if bytes/i = #"^/" [
        ; fgets 会包含换行符，去掉掉末尾的换行符
        ;printf ["read-input len: %d, size: %d^/" (length? buf/buf) (size? buf/buf)]
        i: 0
        while [i < (length? buf/buf)][
            buf/buf/i: bytes/i
            i: i + 1
        ]
        buf/buf/i: null-byte
        ;printf ["read-input len: %d, size: %d^/" (length? buf/buf) (size? buf/buf)]
    ]
]

#enum MetaCommandResult! [
    META_COMMAND_SUCCESS
    META_COMMAND_UNRECOGNIZED_COMMAND
]

#enum PrepareResult! [
    PREPARE_SUCCESS
    PREPARE_UNRECOGNIZED_STATEMENT
    PREPARE_SYNTAX_ERROR
]

#enum ExecuteResult! [
    EXECUTE_SUCCESS
    EXECUTE_TABLE_FULL
]

#enum StatementType! [
    STATEMENT_INSERT
    STATEMENT_SELECT
]

COLUMN_USERNAME_SIZE:   32
COLUMN_EMAIL_SIZE:      255
ID_SIZE:                4
USERNAME_SIZE:          32
EMAIL_SIZE:             255

ID_OFFSET:              0
USERNAME_OFFSET:        ID_OFFSET + ID_SIZE
EMAIL_OFFSET:           USERNAME_OFFSET + USERNAME_SIZE
ROW_SIZE:               ID_SIZE + USERNAME_SIZE + EMAIL_SIZE

PAGE_SIZE:              4096
TABLE_MAX_PAGES:        100
ROWS_PER_PAGE:          PAGE_SIZE / ROW_SIZE
TABLE_MAX_ROWS:         ROWS_PER_PAGE * TABLE_MAX_PAGES

row!: alias struct! [
    id [integer!]
    username [c-string!]
    email [c-string!]
]

table!: alias struct! [
    rows-num [integer!]
    pages [byte-ptr!]
]

statement!: alias struct! [
    type [StatementType!]
    row2insert [row!]
]

copy-row: func [
    src [row!]
    dst [row!]
    /local target len
][
    dst/id: src/id

    len: length? src/username
    target: allocate len
    copy-memory target (as byte-ptr! src/username) len
    dst/username: as-c-string target

    len: length? src/email
    target: allocate len
    copy-memory target (as byte-ptr! src/email) len
    dst/email: as-c-string target
]

print-row: func [
    row [row!]
][
    printf ["(%d, %s, %s)" row/id row/username row/email]
    printf [" at (%d, %d, %d)^/" row/id row/username row/email]
]

new-table: func [
    return: [table!]
    /local tb [table!]
][
    tb: declare table!
    tb/rows-num: 0
    tb/pages: allocate TABLE_MAX_PAGES
    tb
]

row-slot: func [
    table [table!]
    row-num [integer!]
    return: [byte-ptr!]
    /local
        page-num [integer!]
        page [byte-ptr!]
        row-offset [integer!]
        byte-offset [integer!]
][
    page-num: row-num / ROWS_PER_PAGE
    page: table/pages + page-num
    if null? page [
        page: allocate PAGE_SIZE
    ]
    row-offset: row-num % ROWS_PER_PAGE
    byte-offset: row-offset * ROW_SIZE

    page + byte-offset
]

prepare-statement: func [
    buf [InputBuffer!]
    stmt [statement!]
    return: [PrepareResult!]
    /local
        args-assigned [integer!]
        id [integer!]
][
    if zero? strncmp buf/buf "insert" 6 [
        stmt/type: STATEMENT_INSERT
        id: 0
        args-assigned: sscanf [
            buf/buf "insert %d %s %s"
            :id                     ; 应该传入指针
            ;stmt/row2insert/id
            stmt/row2insert/username
            stmt/row2insert/email]

        if args-assigned < 3 [
            return PREPARE_SYNTAX_ERROR
        ]
        stmt/row2insert/id: id

        printf ["=>sscanf ok, id:%d, name:%s, email:%s at %d, %d, %d^/"
                id stmt/row2insert/username stmt/row2insert/email
                id stmt/row2insert/username stmt/row2insert/email]

        return PREPARE_SUCCESS
    ]
    if zero? strcmp buf/buf "select" [
        stmt/type: STATEMENT_SELECT
        return PREPARE_SUCCESS
    ]
    PREPARE_UNRECOGNIZED_STATEMENT
]

execute-insert: func [
    stmt [statement!]
    table [table!]
    return: [ExecuteResult!]
    /local
        row2insert [row!]
        slot [byte-ptr!]
][
    if table/rows-num >= TABLE_MAX_ROWS [
        return EXECUTE_TABLE_FULL
    ]
    row2insert: stmt/row2insert
    slot: row-slot table table/rows-num
    copy-row row2insert (as row! slot)
    table/rows-num: table/rows-num + 1

    return EXECUTE_SUCCESS
]

execute-select: func [
    stmt [statement!]
    table [table!]
    return: [ExecuteResult!]
    /local
        row [row!]
        slot [byte-ptr!]
        i [integer!]
][
    i: 0
    row: declare row! 
    while [i < table/rows-num][
        slot: row-slot table i
        copy-row (as row! slot) row
        print-row row
        i: i + 1
    ]
    return EXECUTE_SUCCESS
]

execute-statement: func [
    stmt [statement!]
    table [table!]
    return: [ExecuteResult!]
][
    ;print-line ["stmt/type: " stmt/type]
    switch stmt/type [
        STATEMENT_INSERT [
            return execute-insert stmt table
        ]
        STATEMENT_SELECT [
            return execute-select stmt table
        ]
    ]
]

do-meta-command: func [
    buf [InputBuffer!]
    return: [MetaCommandResult!]
][
    if any [
        zero? strcmp buf/buf ".exit" 
        zero? strcmp buf/buf ".q"
        zero? strcmp buf/buf "q"
    ][
        printf "Bye~^/"
        quit EXIT_SUCCESS
    ]
    META_COMMAND_UNRECOGNIZED_COMMAND
]

main: func [
    /local
        buf [InputBuffer!]
        stmt [statement!]
        table [table!]
][
    buf: declare InputBuffer!
    buf: new-input-buffer
    stmt: declare statement!
    stmt/row2insert: declare row!
    stmt/row2insert/username: declare c-string!
    stmt/row2insert/email: declare c-string!
    table: new-table

    forever [
        print "db > "
        read-input buf

        if zero? strcmp buf/buf "" [continue]
        if any [
            buf/buf/1 = #"."
            buf/buf/1 = #"q"
        ][
            switch do-meta-command buf [
                META_COMMAND_SUCCESS [
                    continue
                ]
                META_COMMAND_UNRECOGNIZED_COMMAND [
                    if zero? strcmp buf/buf "" [continue]
                    printf ["Unrecognized command '%s'.^/^/" buf/buf]
                    continue
                ]
            ]
        ]

        switch prepare-statement buf stmt [
            PREPARE_SUCCESS [

            ]
            PREPARE_SYNTAX_ERROR [
                printf ["Syntax error. Could not parse statement.^/^/" buf/buf]
                continue
            ]
            PREPARE_UNRECOGNIZED_STATEMENT [
                printf ["Unrecognized keyword at start of '%s'.^/^/" buf/buf]
                continue
            ]
        ]

        switch execute-statement stmt table [
            EXECUTE_SUCCESS [
                printf "=>Excuted.^/"
            ]
            EXECUTE_TABLE_FULL [
                printf "Error: Table full.^/"
            ]
        ]
    ]
]

main


