// A Java program for Prim's Minimum Spanning Tree (MST) algorithm.
// The program is for adjacency matrix representation of the graph

import java.util.*;
import java.lang.*;
import java.io.*;
import java.nio.*;
import java.nio.file.*;
import java.security.Key;

public class SpanningTree {
	// Number of vertices in the graph
	private static int V;
	Map<String, Integer> nodes = new HashMap<String, Integer>(); // node symbol to index
	Map<String, Integer> degree = new HashMap<String, Integer>(); // degree in the original graph!
	Map<Integer, String> nodes_mirror = new HashMap<Integer, String>(); // node index to symbol
	Map<String, ArrayList<String>> TREE = new HashMap<String, ArrayList<String>>();
	Map<String, String> QueryFiles = new HashMap<String, String>();
	Map<String, StringBuilder> RoutingData = new HashMap<String, StringBuilder>();
	int graph[][];



	int parent[];
	private void SetSize(int v) {
		V = v; 
		parent = new int[V];
	}

	// A utility function to find the vertex with minimum key
	// value, from the set of vertices not yet included in MST
	int minKey(int key[], Boolean mstSet[])
	{
		// Initialize min value
		int min = Integer.MAX_VALUE, min_index = -1;

		for (int v = 0; v < V; v++)
			if (mstSet[v] == false && key[v] < min) {
				min = key[v];
				min_index = v;
			}

		return min_index;
	}

	void printTree(String filename)
	{
		try {
			File myObj = new File(filename);
			myObj.delete();
			if (myObj.createNewFile()) {
				FileWriter fw = new FileWriter(myObj);
				System.out.println("Tree file: " + myObj.getName());
				for (int i = 1; i < V; i++) {
					String u = nodes_mirror.get(parent[i]);
					String v = nodes_mirror.get(i);
					String line = u + "  " + v + "\t" + graph[i][parent[i]] + "\n";
					fw.write(line);

					if(!TREE.containsKey(u))
						TREE.put(u, new ArrayList<String>());
					if(!TREE.containsKey(v))
						TREE.put(v, new ArrayList<String>());
					TREE.get(v).add(u);
					TREE.get(u).add(v);
				}
				fw.close();
			} else {
				System.out.println("File already exists.");
			}
		} catch (IOException e) {
			System.out.println("An error occurred.");
			e.printStackTrace();
			return;
		}

		Set<String> keys = TREE.keySet();
		int max = 0;
		for(String key: keys) {
			if(TREE.get(key).size() > max) {
				max = TREE.get(key).size();
			}
			// System.out.println(key + " " + TREE.get(key).size());
		}
		System.out.println("Max Degree: " + max);

	}

	// Function to construct and print MST for a graph represented
	// using adjacency matrix representation
	void primMST() { 
		System.out.println("Build Tree: V:" + V);
		// Key values used to pick minimum weight edge in cut
		int key[] = new int[V];

		// To represent set of vertices included in MST
		Boolean mstSet[] = new Boolean[V];

		// Initialize all keys as INFINITE
		for (int i = 0; i < V; i++) {
			key[i] = Integer.MAX_VALUE;
			mstSet[i] = false;
		}

		// Always include first 1st vertex in MST.
		key[0] = 0; // Make key 0 so that this vertex is
		// picked as first vertex
		parent[0] = -1; // First node is always root of MST

		// The MST will have V vertices
		for (int count = 0; count < V - 1; count++) {
			// Pick thd minimum key vertex from the set of vertices
			// not yet included in MST
			int u = minKey(key, mstSet);

			// Add the picked vertex to the MST Set
			mstSet[u] = true;

			// Update key value and parent index of the adjacent
			// vertices of the picked vertex. Consider only those
			// vertices which are not yet included in MST
			for (int v = 0; v < V; v++)

				// graph[u][v] is non zero only for adjacent vertices of m
				// mstSet[v] is false for vertices not yet included in MST
				// Update the key only if graph[u][v] is smaller than key[v]
				if (graph[u][v] != 0 && mstSet[v] == false && graph[u][v] < key[v]) {
					parent[v] = u;
					key[v] = graph[u][v];
				}
		}

	}

	void dfs(String node, Set<String> visited, int intf, String key) throws Exception{
		visited.add(node);
		// String command = "sed s/$/:fwd\\("+intf+"\\)\\;/ ./queries/"+node+".query >> ./routing/"+key+".filters \n";
		// fw.write(node + " ");
		// fw.write(command);
		writeForward(node, key, intf);
		int size = TREE.get(node).size();

		for(int i = 0; i < size; i++) {
			String n = TREE.get(node).get(i);
			if(!visited.contains(n)) {
				dfs(n, visited, intf, key);
			}
		}
	}

	void loadQueryFiles() throws Exception {
		Set<String> keys = TREE.keySet();
		for(String key: keys) {
			Path fileName = Path.of("./queries/" + key + ".query");
			String queryContent = "";
			try {
				queryContent = Files.readString(fileName);
			} catch(Exception e) { }
			QueryFiles.put(key, queryContent);
		}
	}

	static boolean leaf_node_one_is_enough = false;
	public void writeForwardAllExcept(String src)  throws Exception{
		if(leaf_node_one_is_enough)
			return;
		Set<String> keys = QueryFiles.keySet();
		StringBuilder tmpQueryFile = new StringBuilder();

		for(String key: keys) {
			String q = QueryFiles.get(key);
			String queryFile = new String(q);

			if(queryFile.length() < 2)
				continue;
			if(key.equals(src)) {
				queryFile = queryFile.replaceAll("[\\t\\n\\r]+", ": fwd(0);\n");
			}else{
				queryFile = queryFile.replaceAll("[\\t\\n\\r]+", ": fwd(1);\n");
			}
			tmpQueryFile.append(queryFile);
		}

		Path fileName = Path.of("./routing/" + src + ".filters");
		if(Files.notExists(fileName))
			Files.createFile(fileName);
		Files.writeString(fileName, tmpQueryFile, StandardOpenOption.APPEND);
		leaf_node_one_is_enough = true;
	}

	public void writeForward(String src, String dst, int intf)  throws Exception{
		String queryFile = QueryFiles.get(src);
		queryFile = queryFile.replaceAll("[\\t\\n\\r]+", ": fwd("+intf+");\n");
		if(!RoutingData.containsKey(dst))
			RoutingData.put(dst, new StringBuilder());
		RoutingData.get(dst).append(queryFile);
	}

	void feelRoutingFile() throws Exception{
		loadQueryFiles();
		Set<String> keys = TREE.keySet();
		for(String key: keys) {
			int n = TREE.get(key).size();
			if(n == 1) {
				writeForwardAllExcept(key);
				continue;
			} 
				
			for(int i = 0; i < n; i++) {
				Set<String> visitedNodes = new HashSet<String>();
				visitedNodes.add(key);
				dfs(TREE.get(key).get(i), visitedNodes, i + 1, key);
			}
			writeForward(key, key, 0);
		}
		System.out.println("Writing into Routing Files!");

		keys = RoutingData.keySet();
		for (String dst : keys) {
			Path fileName = Path.of("./routing/" + dst + ".filters");
			if(Files.notExists(fileName))
				Files.createFile(fileName);
			Files.writeString(fileName, RoutingData.get(dst), StandardOpenOption.APPEND);
		}
	}
	
	public static void printUsage() {
		System.out.println("Java SpanningTree <graph-file> <ouptut-tree>");
	}

	public int[][] loadGraph(String args) throws Exception{
		try (BufferedReader br = new BufferedReader(new FileReader(args))) {
			String line;
			while ((line = br.readLine()) != null) {
				line = line.trim();
				String[] vars = line.split("\\s+");
				
				if(line.charAt(0) == '#') { 
					if(line.contains("Title")) {
						System.out.println("Loading: " + line.substring(line.lastIndexOf(" ")));
					}
				} else {
					String u = vars[0];
					String v = vars[1];
					
					if(!nodes.containsKey(u)) {
						nodes.put(u, nodes.size());
						nodes_mirror.put(nodes.get(u), u);
						degree.put(u, 0);
					}
					if(!nodes.containsKey(v)) {
						nodes.put(v, nodes.size());
						nodes_mirror.put(nodes.get(v), v);
						degree.put(v, 0);
					}
					degree.put(v, degree.get(v)+1);
					degree.put(u, degree.get(u)+1);
				}
			}
		}

		graph = new int [nodes.size()][];
		for(int i = 0; i < nodes.size(); i++){
			graph[i] = new int[nodes.size()];
			for(int j = 0; j < nodes.size();j++)
				graph[i][j] = 0;
		}
		try (BufferedReader br = new BufferedReader(new FileReader(args))) {
			String line;
			while ((line = br.readLine()) != null) {
				line = line.trim();
				if(line.charAt(0) == '#') continue;

				String[] vars = line.split("\\s+");
				String u = vars[0];
				String v = vars[1];
				int w = degree.get(v) * degree.get(u) + 1; 
				// int w = 1; // default weight!
				if(vars.length > 2) 
					w = Integer.valueOf(vars[2]);
				graph[nodes.get(u)][nodes.get(v)] = w;
				graph[nodes.get(v)][nodes.get(u)] = w; 
			}
		}
		SetSize(nodes.size());
		return graph;
	}

	public static void main(String[] args) throws Exception {
		if(args.length != 2) {
			printUsage();
			return;
		}

		SpanningTree t = new SpanningTree(); 
		t.loadGraph(args[0]);
		t.primMST();
		t.printTree(args[1]);
		t.feelRoutingFile();
	}
}
// This code is contributed by Aakash Hasija
