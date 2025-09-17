{
	description = "Minecraft server";

	inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";

	outputs =
		{ self, nixpkgs, ... }@inputs:
		let
			supportedSystems = nixpkgs.lib.platforms.all;

			mkMinecraftServerPackage = (pkgs: server: mods: 
				pkgs.stdenv.mkDerivation {
					name = "minecraft-server";
					version = "1.0.0";
					src = ./.;

					nativeBuildInputs = [ pkgs.makeWrapper ];

					installPhase = 
						let
							shareDirectory = "$out/share/minecraft-server";
							serverPath = "${shareDirectory}/server.jar";
							modsDirectory = "${shareDirectory}/mods";

							binDirectory = "$out/bin";
							binName = "minecraft-server";
							binPath = "${binDirectory}/${binName}";


							copyModCommand = name: file: "cp ${file} ${modsDirectory}/${name}.jar";
							copyModCommands = pkgs.lib.mapAttrsToList copyModCommand mods;
						in
						''
							mkdir -p ${binDirectory}
							mkdir -p ${shareDirectory}
							mkdir -p ${modsDirectory}

							${pkgs.lib.concatStringsSep "\n" copyModCommands}

							cp ${server} ${serverPath}

							makeWrapper ${pkgs.temurin-jre-bin}/bin/java ${binPath} \
								--prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.coreutils ]} \
								--add-flags "-jar ${serverPath} nogui" \
								--run "export MINECRAFT_DATA=\''${MINECRAFT_DATA:-\$(pwd)}" \
								--run "cd \"\$MINECRAFT_DATA\"" \
								--run "ln -sf ${modsDirectory} \"\$MINECRAFT_DATA/mods\"";
						'';

					meta.mainProgram = "minecraft-server";
				}
			);

			mkHorkromServer = (system:
				let
					pkgs = import nixpkgs { inherit system; };

					server = pkgs.fetchurl {
						url = "https://meta.fabricmc.net/v2/versions/loader/1.21.8/0.17.2/1.1.0/server/jar";
						sha256 = "08km5kfw0rs9xfya0j7kr41b4h9a5ql7iwbhzaqzmss5nrnnxxl0";
					};
					
					mods = {
						distant_horizons = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/uCdwusMi/versions/9yaYzpcr/DistantHorizons-2.3.4-b-1.21.8-fabric-neoforge.jar";
							sha256 = "13x1icdnzdh7w0mi1wr556yip5qhyjb5d8nw9v5qh2pkadklbfxd";
						};
						xaeros_world_map = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/NcUtCpym/versions/d1Pc1nIN/XaerosWorldMap_1.39.13_Fabric_1.21.8.jar";
							sha256 = "1dj1a8p2lxknhcjvyhpra2h6qkd2bk2f3g7lxgrl1cfh76509nvb";
						};
						xaeros_minimap = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/1bokaNcj/versions/StqWcPqA/Xaeros_Minimap_25.2.12_Fabric_1.21.8.jar";
							sha256 = "057n97p37qg28pklshyyn9xp09gw872323inllfckrki5y1gz15p";
						};
						bluemap = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/swbUV1cr/versions/plVwynim/bluemap-5.11-fabric.jar";
							sha256 = "0ji55n7d5mb5i2901i46xc6jgrcb4dk2sjwz58dlmahwjich6h0l";
						};
						fabric_api = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/CF23l2iP/fabric-api-0.133.4+1.21.8.jar";
							sha256 = "16f0aqixcwq7ixq3pr1h2yc1m1fyxihiz9m61dcdq5784l8ifvv8";
						};
					};

					minecraftServer = mkMinecraftServerPackage pkgs server mods;
				in
				{ 
					default = minecraftServer;
				}
			);
		in
		{
			packages = nixpkgs.lib.genAttrs supportedSystems mkHorkromServer;
		};
}
