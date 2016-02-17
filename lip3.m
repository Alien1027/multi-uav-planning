function [X,v,m] = lip3(V,uav,uavSpeed,uavSetupTime,uavFlightTime,h,O)

% constru��o da matriz de custos
C = zeros(length(V));
numberOfVertices = length(V);
uavNumber = length(uav);

for i = 1:numberOfVertices
    for j = 1:numberOfVertices
        if i ~= j
            C(i,j) = norm(V(i,:)-V(j,:))/(uavSpeed*1000/60);
        end
    end
end

%% Linear Integer Programming
v = sdpvar(1,1);
X = binvar(numberOfVertices,numberOfVertices,uavNumber,'full');
u = sdpvar(numberOfVertices,1);
m = intvar(1,1);
for k = 1:uavNumber
    for i = 1:numberOfVertices
        X(i,i,k) = 0;
    end
    if uav(k) == 0
        X(:,:,k) = zeros(numberOfVertices);
    end
end

constraints = [];

%% Retri��es
% Restri��o #1 - Custo total de opera��o
for k = 1:uavNumber
    sum1 = 0;
    for i = 1:numberOfVertices
        for j = 1:numberOfVertices
            if i ~= j
                sum1 = sum1 + C(i,j)*sum(X(i,j,k));
            end
        end
    end
    constraints = [constraints, v >= sum1 + sum(X(1,:,k))*ceil(k/O)*uavSetupTime];
    % Restri��o 9 - Autonomia de Voo
    constraints = [constraints, sum1 <= uavFlightTime];
end

% Restri��o 2 - Cada v�rtice deve ser visitado uma vez e por um vant
for j = 2:numberOfVertices
    constraints = [constraints, sum(sum(X(:,j,:))) == 1];
end

% Restri��o 3 - Ao visitar um v�rtice, o vant deve sair daquele v�rtice
for k = 1:uavNumber
    for p = 1:numberOfVertices
        constraints = [constraints, sum(X(:,p,k)) - sum(X(p,:,k)) == 0];
    end
end

% Restri��o 4 e 5 - N�mero de vants utilizado
constraints = [constraints, sum(sum(X(1,:,:))) == m];
% if sum(uav) < length(uav)
%     constraints = [constraints, m == sum(uav)];
% else
%     constraints = [constraints, m <= uavNumber];
% end
constraints = [constraints, m <= sum(uav)];

% Restri��o 6 - ???
% for k = 1:uavNumber
%     constraints = [constraints, sum(X(1,2:numberOfVertices,k)) == 1];
% end

% Restri��o 7 - Ciclo
for i = 2:numberOfVertices
    for j = 2:numberOfVertices
        if i ~= j
            constraints = [constraints, u(i) - u(j) + numberOfVertices*sum(X(i,j,:)) <= numberOfVertices - 1];
        end
    end
end

% Restri��o 8 - Aquela que obriga que cada linha seja percorrida por apenas
% um VANT e em apenas um sentido.
for i = 2:2:numberOfVertices
   constraints = [constraints, 1 == sum(X(i,i+1,:)) + sum(X(i+1,i,:))];
end

% Restri��o 10 - Evita diagonais
for i = 2:2:numberOfVertices
   constraints = [constraints, sum(X(i,i+1,:)) == sum(sum(X(i,3:2:numberOfVertices,:)))];
   constraints = [constraints, sum(X(i+1,i,:)) == sum(sum(X(i+1,2:2:numberOfVertices,:)))];
end

% minimiza v sujeito as restri��es contidas na vari�vel constraints
% com gurobi
%options = sdpsettings('solver','gurobi','verbose',1,'gurobi.Threads',4);
% sem gurobi
options = sdpsettings('verbose',1,'gurobi.Threads',4);
if h == 1
    solvesdp(constraints,0.999*max(v)+0.001*mean(v),options);
    %solvesdp(constraints,max(v),options);
elseif h == 0
    solvesdp(constraints,v,options);
end

X = round(double(X));
for k = 1:uavNumber
    sum1 = 0;
    for i = 1:numberOfVertices
        for j = 1:numberOfVertices
            if i ~= j
                sum1 = sum1 + C(i,j)*sum(X(i,j,k));
            end
        end
    end
    v(k) = sum1 + sum(X(1,:,k))*k*uavSetupTime;
end
m = round(double(m));