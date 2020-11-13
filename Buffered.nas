#
# Authors: Axel Paccalin.
#
# Version 0.1
#
# Imported under "FGUM_Contact" 
#
# Module to create a way to temporarily store the result of an expression through multiple acces.
# Expressions evaluations (and the ones of their derived classes) are mutually exclusive (thread-safe).
#

#! \brief   Merge two maps into one.
#! \param   exprMapA: The first map.
#! \param   exprMapB: The second map.
#! \return  The merged map.
#! \warning Can throw an exception if the two maps contains the same entry.
mapMerge = func(exprMapA, exprMapB){
    var res = {};
    
    foreach(var i; keys(exprMapA))
        if(res[i] != nil)
            die("error: expression \"" ~ i ~ "\" already defined");  # Should never happen as a single map cannot contain the same entry twice.
        else
            res[i] = exprMapA[i];
       
    foreach(var i; keys(exprMapB))
        if(res[i] != nil)
            die("error: expression \"" ~ i ~ "\" already defined");
        else
            res[i] = exprMapB[i];
    
    return res;
};

# A buffered expression.
Expression = {
    #! \brief Expression default constructor.
    new: func(){
        var me = {parents: [Expression]};
        
        me.accessorMutex = thread.newlock();
        
        me.buffer = nil;
        
        return me;
    },
    
    #! \brief Virtual expression evaluation method.
    eval: nil,
    
    #! \brief   Buffered evaluation accessor.
    #! \details If the buffer is empty, it will be set as the result of the evaluation method. 
    #!          If it is not empty, the evaluation method won't be used ant it will be returned "as is".
    #! \return  The expression evaluation result.
    get: func(){
        thread.lock(me.accessorMutex);
        if(me.buffer == nil)
            me.buffer = me.eval();
        thread.unlock(me.accessorMutex);
        return me.buffer;
    },
    
    #! \brief   Reset the buffer content.
    #! \details Will force a new evaluation of the expression on the next `get()` call.
    reset: func(){
        thread.lock(me.accessorMutex);
        me.buffer = nil;
        thread.unlock(me.accessorMutex);
    },
};

# A buffered accessor.
Accessor = {
    #! \brief Accessor constructor.
    #! \param accessor: The expensive accessor to buffer.
    new: func(accessor){
        var me = {parents: [Accessor, Expression.new()]};
        
        me.eval = func(){return accessor();};
        
        return me;
    },
};

# A buffered property (from the FG property tree) accessor.
PropertyAccessor = {
    #! \brief PropertyAccessor constructor.
    #! \param prop: The property-tree property linked.
    new: func(prop){
        var me = {parents: [PropertyAccessor, Accessor.new(prop.getValue)]};
        
        return me;
    },
};

# A map to store buffered expressions.
Map = {
    #! \brief Map constructor.
    #! \param expressionMap: The map of expressions to be based on ({exprName: expr, ...}).
    new: func(expressionMap){
        var me = {parents: [Map]};
        me._exprMap = expressionMap;
        
        foreach(var exprName; keys(me._exprMap)){            
            me["get" ~ exprName] = bind(func(){return expr.get()}, {expr: me._exprMap[exprName]});
        }
            
        return me;
    },
    
    #! \brief   Reset the buffer content of all expressions contained in the map.
    reset: func(){
        foreach(var i; keys(me._exprMap))
            me._exprMap[i].reset();
    },
};
