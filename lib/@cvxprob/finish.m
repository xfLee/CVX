function finish( prob )

global cvx___
[ p, pstr ] = verify( prob );

try

if isempty( pstr.objective ) && isempty( pstr.variables ) && nnz( pstr.t_variable ) == 1,

    warning( 'CVX:EmptyModel', 'Empty cvx model; no action taken.' );

elseif pstr.complete && nnz( pstr.t_variable ) == 1,

    %
    % Check the integrity of the variables
    %

    vars = pstr.variables;
    if isempty( vars ),
        fn1 = cell( 0, 1 );
        vv1 = fn1;
    else
        fn1  = fieldnames( vars );
        ndxs = cellfun( @(x)x(end)~='_', fn1 );
        fn1  = fn1( ndxs );
        vv1  = struct2cell( vars );
        vv1  = vv1(ndxs);
    end
    if isempty( pstr.duals ),
        fn2 = cell( 0, 1 );
        vv2 = fn2;
    else
        fn2  = fieldnames( pstr.duals );
        ndxs = cellfun( @(x)x(end)~='_', fn2 );
        fn2  = fn2( ndxs );
        vv2  = struct2cell( pstr.dvars );
        vv2  = vv2( ndxs );
    end
    fn1 = [ fn1 ; fn2 ];
    i1  = cellfun( @cvx_id, [ vv1 ; vv2 ] )';
    i2  = evalin( 'caller', [ 'cellfun( @cvx_id, {', sprintf( '%s ', fn1{:} ), '} )' ] );
    if any( i1 ~= i2 ),
        cvx_pop( p, true );
        temp = sprintf( ' %s', fn1{ i1 ~= i2 } );
        error( 'CVX:CorruptModel', 'The following cvx variable(s) have been cleared or overwritten:\n  %s\nThis is often an indication that an equality constraint was\nwritten with one equals ''='' instead of two ''==''. The model\nmust be rewritten before CVX can solve it.', temp );
    end

    clear pstr;
    solve( prob );
    pstr = cvx___.problems( p );
    
    if numel( pstr.objective ) > 1 && ~isempty( pstr.result ),
        if strfind( pstr.status, 'Solved' ),
            pstr.result = value( pstr.objective );
            if pstr.geometric, pstr.result = exp( pstr.result ); end
        else
            pstr.result = pstr.result * ones(size(pstr.objective));
        end
    end

    assignin( 'caller', 'cvx_status',  pstr.status );
    assignin( 'caller', 'cvx_optval',  pstr.result );
    assignin( 'caller', 'cvx_optbnd',  pstr.bound );
    assignin( 'caller', 'cvx_slvitr',  pstr.iters );
    assignin( 'caller', 'cvx_slvtol',  pstr.tol );
    assignin( 'caller', 'cvx_cputime', cputime - pstr.cputime );
    
elseif length( cvx___.problems ) < 2,

    cvx_pop( 0, true );
    error( 'CVX:InternalError', 'Internal CVX data corruption. Please CLEAR ALL and rebuild your model.' );

else
    
    np = p - 1;
    vars = cvx_collapse( pstr.variables, true, false );
    dvars = cvx_collapse( pstr.duals, true, false );
    if ~isempty( vars ) || ~isempty( dvars ),
        pname = [ pstr.name, '_' ];
        if ~isempty( vars ),
            try
                ovars = cvx___.problems(np).variables.(pname);
            catch
                ovars = {};
            end
            ovars{end+1} = vars;
            cvx___.problems(np).variables.(pname) = ovars;
        end
        if ~isempty( dvars ),
            try
                ovars = cvx___.problems(np).duals.(name);
            catch
                ovars = {};
            end
            ovars{end+1} = dvars;
            cvx___.problems(np).duals.(pname) = ovars;
        end
    end

    %
    % Merge the touch information
    %
    
    v = cvx___.problems( np ).t_variable;
    v = v | pstr.t_variable( 1 : size( v, 1 ), : );
    cvx___.problems( np ).t_variable = v;
    % Signal to cvx_pop that we have no variables to remove
    cvx___.problems( p ).t_variable = [];

    %
    % Process the objective and optimal point, converting to pure
    % epigraph/hypograph form if necessary
    %

    x = pstr.objective;
    if isempty( x ),

        assignin( 'caller', 'cvx_optval', 0 );
        temp = length( pstr.t_variable ) + 1 : length( cvx___.readonly );
        cvx___.readonly( temp ) = cvx___.readonly( temp ) - 1;

    else

        switch pstr.direction,
            case { 'minimize', 'minimise' },
                force = false;
                os = +1;
            case 'epigraph',
                force = true;
                os = +1;
            case { 'maximize', 'maximise' },
                force = false;
                os = -1;
            case 'hypograph',
                force = true;
                os = -1;
        end
        
        if ~force,
            x = sparsify( x, 'objective' );
        end
        xB = cvx_basis( x );
        [ r, c ] = find( xB ); %#ok
        t = r ~= 1; r = r( t );

        %
        % Set the vexity flags
        %

        cvx___.canslack( r, : ) = true;
        cvx___.readonly( r, : ) = np;
        cvx___.classes( r, : ) = int8( cvx___.classes( r, : ) + 3 * os );
        
        %
        % Convert to geometric form if necessary
        %

        tt = pstr.geometric;
        if any( tt ),
            if all( tt ),
                x = exp( x );
            else
                x( tt ) = exp( x( tt ) );
            end
        end

        assignin( 'caller', 'cvx_optval', x );
    end

end

assignin( 'caller', 'cvx_optpnt', cvxtuple( cvx_collapse( vars, false, false ) ) );
evalin( 'caller', 'cvx_pop( cvx_problem )' );

catch exc

    rethrow( exc );
    
end

% Copyright 2005-2014 CVX Research, Inc.
% See the file LICENSE.txt for full copyright information.
% The command 'cvx_where' will show where this file is located.
