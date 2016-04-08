--[[Glass3D, Copyright 2016 Trientalis
This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

  (Это свободная программа: вы можете перераспространять ее и/или изменять
   ее на условиях Стандартной общественной лицензии GNU в том виде, в каком
   она была опубликована Фондом свободного программного обеспечения; либо
   версии 3 лицензии, либо (по вашему выбору) любой более поздней версии.

   Эта программа распространяется в надежде, что она будет полезной,
   но БЕЗО ВСЯКИХ ГАРАНТИЙ; даже без неявной гарантии ТОВАРНОГО ВИДА
   или ПРИГОДНОСТИ ДЛЯ ОПРЕДЕЛЕННЫХ ЦЕЛЕЙ. Подробнее см. в Стандартной
   общественной лицензии GNU.

   Вы должны были получить копию Стандартной общественной лицензии GNU
   вместе с этой программой. Если это не так, см.
   <http://www.gnu.org/licenses/>.)]]
   
   --Как-то, так :)

local bufferPolygons={}
local groups={{isPrimal=true,indexes={}}}
local polygons={}
local vertices={}

local lib={}

local stage=require("component").openperipheral_bridge
local focalLenght=100

local function removeElementFromTable(element,t)
    for i=1,#t do
        if(t[i]==element)then
            table.remove(t,i)
            return t,element
        end
    end
end

local function to2D(vertex)
    local s=focalLenght/(focalLenght-vertex.z)
    return vertex.x*s,vertex.y*s
end

function lib.addVertices3D(vertexList)--lib.addVertices3D({x1,y1,z1,x2,y2,z2...})
    local result={}
    for i=1,#vertexList,3 do
        table.insert(result,lib.addVertex3D(vertexList[i],vertexList[i+1],vertexList[i+2]))
    end
    return result
end
function lib.addVertex3D(x,y,z,h)
    local index=#vertices+1
    vertices[index]={x=x,y=y,z=z,h=h or 1}
    table.insert(groups[1].indexes,index)
    vertices[index].group=groups[1]
    return index
end
function lib.removeVertex3D(index)
    vertices[index]=nil
end


function lib.addPolygon3D(vertexList,fill)--lib.addPolygon3D({v1,v2,v3},{color=0xffffff,opacity=1 or nil})
    table.sort(vertexList)
    local name=""..vertexList[1].."_"..vertexList[2].."_"..vertexList[3]
    if(polygons[name])then return "polygon alrady created" end
    polygons[name]={}
    local object=polygons[name]
    object.name=name
    object.vertexList=vertexList
    object.fill=fill
    table.insert(bufferPolygons,object)
    return name
end
function lib.removePolygon3D(name)
    removeElementFromTable(polygons[name],bufferPolygons)
    polygons[name]=nil
end

local function removeFromGroup(index,group)
    removeElementFromTable(index,group)
    vertices[index].group=groups[1]
end


function lib.transform(vertexIndexList,matrix)--lib.transform({v1,v2,v3,...},{numbers...}) #matrix==16
    local groupList={}
    for i=1,#vertexIndexList do
        local index=vertexIndexList[i]
        local group=vertices[index].group
        groupList[group]=groupList[group] or {}
        groupList[group].indexes=groupList[group].indexes or {}
        table.insert(groupList[group].indexes,index)
        if(not groupList[group].matrix)then
            if(group.matrix)then
                local result={};
		        for i=1,4 do
                    for j=1,4 do
			            result[i+4*(j-1)] = 0.0;
			            for k=1,4 do
                        result[i+4*(j-1)] = result[i+4*(j-1)]+group.matrix[i+(k-1)*4]*matrix[k+4*(j-1)]
                        end
                    end
                end
                groupList[group].matrix=result
            else
                groupList[group].matrix=matrix
            end
        end
        removeFromGroup(vertexIndexList[i],group)
        if(#group.indexes==0 and not group.isPrimal)then removeElementFromTable(groups,group) end
        vertices[index].group=groupList[group]
        table.insert(groups,groupList[group])
    end
end


function lib.update()
    stage.clear()
    for i=1,#groups do
        local group=groups[i]
        local matrix=group.matrix
        if(matrix)then
            for i=1,#group.indexes do--Применяем матрицы
                local vertex=vertices[group.indexes[i]]
                local x=matrix[1]*vertex.x+matrix[2]*vertex.y+matrix[3]*vertex.z+matrix[4]*vertex.h
                local y=matrix[5]*vertex.x+matrix[6]*vertex.y+matrix[7]*vertex.z+matrix[8]*vertex.h
                local z=matrix[9]*vertex.x+matrix[10]*vertex.y+matrix[11]*vertex.z+matrix[12]*vertex.h
                local h=matrix[13]*vertex.x+matrix[14]*vertex.y+matrix[15]*vertex.z+matrix[16]*vertex.h
                vertex.x=x*h
                vertex.y=y*h
                vertex.z=z*h
                vertex.h=1
                removeFromGroup(group.indexes[i],group)
                vertex.group=groups[1]
            end
        end
    end
    local depthArray={}--Z-сортировка, она не обработает полигоны попиксельно, но сгодится для непересекающихся
    for j=1,#bufferPolygons do
        local depth=0
        local vertexList=bufferPolygons[j].vertexList
        for i=1,3 do
            depth=depth+vertices[vertexList[i]].z
        end
        table.insert(depthArray,{bufferPolygons[j],depth})
    end
    table.sort(depthArray,function(a,b)return a[2]>b[2] end)
    for j=1,#depthArray do
        local x1,y1=to2D(vertices[depthArray[j][1].vertexList[1]])
        local x2,y2=to2D(vertices[depthArray[j][1].vertexList[2]])
        local x3,y3=to2D(vertices[depthArray[j][1].vertexList[3]])
        local fill=depthArray[j][1].fill
        local polygon=stage.addPolygon(fill.color,fill.opacity or 1,{x=x1,y=y1},{x=x2,y=y2},{x=x3,y=y3})
        polygon.setScreenAnchor("MIDDLE","MIDDLE")
    end
    stage.sync()
end

function lib.setFocalLenght(newFocalLenght)--Расстояние от глаза до экрана
    focalLenght=newFocalLenght
    return focalLenght
end


function lib.getFocalLenght()
    return focalLenght
end


return lib