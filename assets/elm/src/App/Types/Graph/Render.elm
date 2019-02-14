module App.Types.Graph.Render exposing (render)

import App.Ports.Graph exposing (Node)
import App.Types.Coto exposing (Coto, Cotonoma)
import App.Types.Graph exposing (Graph)
import Dict
import Exts.Maybe exposing (isJust)
import Set


render : Maybe Cotonoma -> Graph -> Cmd msg
render currentCotonoma graph =
    doRenderCotoGraph
        (currentCotonomaToNode graph currentCotonoma)
        (toTopicGraph graph)


doRenderCotoGraph : Node -> Graph -> Cmd msg
doRenderCotoGraph root graph =
    let
        nodes =
            graph.cotos
                |> Dict.values
                |> List.map (cotoToNode graph)

        rootEdges =
            graph.rootConnections
                |> List.map
                    (\conn ->
                        { source = root.id
                        , target = conn.end
                        }
                    )

        edges =
            graph.connections
                |> Dict.toList
                |> List.map
                    (\( sourceId, conns ) ->
                        List.map
                            (\conn ->
                                { source = sourceId
                                , target = conn.end
                                }
                            )
                            conns
                    )
                |> List.concat
    in
    App.Ports.Graph.renderGraph
        { rootNodeId = root.id
        , nodes = root :: nodes
        , edges = rootEdges ++ edges
        }


cotoToNode : Graph -> Coto -> Node
cotoToNode graph coto =
    { id = coto.id
    , name = App.Types.Coto.toTopic coto |> Maybe.withDefault ""
    , pinned = App.Types.Graph.pinned coto.id graph
    , asCotonoma = isJust coto.asCotonoma
    , imageUrl = Maybe.map .avatarUrl coto.amishi
    }


currentCotonomaToNode : Graph -> Maybe Cotonoma -> Node
currentCotonomaToNode graph currentCotonoma =
    currentCotonoma
        |> Maybe.map
            (\cotonoma ->
                { id = cotonoma.cotoId
                , name = cotonoma.name
                , pinned = False
                , asCotonoma = True
                , imageUrl = Maybe.map .avatarUrl cotonoma.owner
                }
            )
        |> Maybe.withDefault
            { id = "home"
            , name = ""
            , pinned = False
            , asCotonoma = False
            , imageUrl = Nothing
            }


toTopicGraph : Graph -> Graph
toTopicGraph graph =
    let
        topicCotos =
            graph.cotos
                |> Dict.filter
                    (\cotoId coto ->
                        isJust (App.Types.Coto.toTopic coto)
                    )
    in
    { graph | cotos = topicCotos }
        |> deleteInvalidConnections
        |> excludeUnreachables


excludeUnreachables : Graph -> Graph
excludeUnreachables graph =
    let
        reachableCotos =
            Dict.filter
                (\cotoId coto -> Set.member cotoId graph.reachableCotoIds)
                graph.cotos
    in
    { graph | cotos = reachableCotos }
        |> deleteInvalidConnections


deleteInvalidConnections : Graph -> Graph
deleteInvalidConnections graph =
    let
        rootConnections =
            graph.rootConnections
                |> List.filter (\conn -> Dict.member conn.end graph.cotos)

        connections =
            graph.connections
                |> Dict.toList
                |> List.filterMap
                    (\( sourceId, conns ) ->
                        if Dict.member sourceId graph.cotos then
                            Just
                                ( sourceId
                                , List.filter
                                    (\conn -> Dict.member conn.end graph.cotos)
                                    conns
                                )

                        else
                            Nothing
                    )
                |> Dict.fromList
    in
    { graph | rootConnections = rootConnections, connections = connections }
