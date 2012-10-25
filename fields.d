module dpq2.fields;

import dpq2.answer;
import dpq2.libpq;
import std.string;

struct Field( T, string sqlName, string sqlPrefix = "", string decl = "" )
{
    alias T type;
    
    static string toString() pure nothrow
    {
        return "\""~( sqlPrefix.length ? sqlPrefix~"."~sqlName : sqlName )~"\"";
    }
    
    static string toDecl() pure nothrow
    {
        return decl.length ? decl : (sqlPrefix.length ? sqlPrefix~"_"~sqlName : sqlName);
    }
    
    static string toRowFieldProperty( size_t n )
    {
        return "@property auto "~toDecl()~"()"
            "{return getVal!("~to!string(n)~");}";
    }
}

struct Fields( TL ... )
{
    private static
    string joinFieldString( string memberName, bool passIter = false )( string delimiter )
    {
        string r;
        foreach( i, T; TL )
        {
            mixin( "r ~= T." ~ memberName ~ "("~(passIter ? to!string(i) : "")~");" );
            if( i < TL.length-1 ) r ~= delimiter;
        }
        
        return r;
    }
    
    @property
    static string toString() nothrow
    {
        return joinFieldString!("toString")(", ");
    }
    
    private static string GenFieldsEnum() nothrow
    {
        return joinFieldString!("toDecl")(", ");
    }
    
    mixin("enum FieldsEnum {"~GenFieldsEnum()~"}");
}

struct RowFields( TL ... )
{
    Fields!(TL) fields;
    alias fields this;
    
    Row* _row;
    
    @property
    void row( ref Row r )
    {
        _row = &r;
    }
    
    @property
    auto getVal( size_t n )()
    {
        return _row.opIndex(n).as!( TL[n].type );
    }
    
    private static string GenRowProperties()
    {
        return fields.joinFieldString!("toRowFieldProperty", true)("");
    }
    
    mixin( GenRowProperties() );
}

void _unittest( string connParam )
{
    auto conn = new Connection;
	conn.connString = connParam;
    conn.connect();
    
    RowFields!(
        Field!(PGtext, "i", "", "INTEGER_FIELD" ),
        Field!(PGtext, "t")
    ) f;
    
    string q = "select "~to!string(f)~"
        from (select 123::integer as i, 'qwerty'::text as t) s";
    auto res = conn.exec( q );
        
    foreach( r; res )
    {
        f.row = r;
        assert( f.INTEGER_FIELD == res[0,0].as!PGtext );
        assert( f.t == res[0,1].as!PGtext );
    }
}
